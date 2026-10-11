package com.sukepuu.randomviewer;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.UriPermission;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.ImageDecoder;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 指定フォルダ内の画像を 1〜6 枠の均等分割グリッドにランダム表示するビューア。
 * 長押しでメニュー、枠のタップで全画面表示、全画面中のタップで元に戻る。
 * メニューの「動画再生モード」からはフォルダ内の動画を {@link VideoActivity} で再生する。
 */
public class MainActivity extends Activity {

    private static final int REQ_PICK_FOLDER = 1;
    private static final int REQ_PICK_VIDEO_FOLDER = 2;

    private static final int MIN_FRAMES = 1;
    private static final int MAX_FRAMES = 6;
    private static final int MIN_INTERVAL = 1;
    private static final int MAX_INTERVAL = 60;
    private static final int DEFAULT_INTERVAL = 10;

    private static final String PREFS = "settings";
    private static final String KEY_TREE_URI = "treeUri";
    private static final String KEY_FRAMES = "frames";
    private static final String KEY_SLIDESHOW = "slideshow";
    private static final String KEY_INTERVAL = "interval";
    private static final String KEY_VIDEO_TREE_URI = "videoTreeUri";

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newFixedThreadPool(3);
    private final Random random = new Random();

    private SharedPreferences prefs;
    private LinearLayout grid;
    private TextView statusView;
    private TextView hintView;
    private ImageView fullscreenView;
    private final ImageView[] cells = new ImageView[MAX_FRAMES];

    /** 各枠に表示中の画像（未表示なら null） */
    private final Uri[] shown = new Uri[MAX_FRAMES];
    private List<Uri> media = new ArrayList<>();

    private Uri treeUri;
    private String folderName = "";
    private boolean loadingFolder;
    /** フォルダ読み込みの世代。古い読み込み結果を捨てるために使う */
    private int folderGeneration;

    private int frameCount = 1;
    private boolean slideshowOn;
    private int intervalSec = DEFAULT_INTERVAL;
    private boolean resumed;

    private final Runnable slideshowTick = new Runnable() {
        @Override
        public void run() {
            showRandomInAllFrames();
            handler.postDelayed(this, intervalSec * 1000L);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        frameCount = clamp(prefs.getInt(KEY_FRAMES, 1), MIN_FRAMES, MAX_FRAMES);
        slideshowOn = prefs.getBoolean(KEY_SLIDESHOW, false);
        intervalSec = clamp(prefs.getInt(KEY_INTERVAL, DEFAULT_INTERVAL), MIN_INTERVAL, MAX_INTERVAL);

        buildViews();
        buildGrid();
        updateStatus();

        String saved = prefs.getString(KEY_TREE_URI, null);
        if (saved != null) {
            Uri uri = Uri.parse(saved);
            if (hasPersistedPermission(uri)) {
                loadFolder(uri);
            } else {
                prefs.edit().remove(KEY_TREE_URI).apply();
            }
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        resumed = true;
        updateSlideshow();
    }

    @Override
    protected void onPause() {
        super.onPause();
        resumed = false;
        updateSlideshow();
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        executor.shutdownNow();
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) SystemBars.hide(getWindow());
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        // 画面の向きが変わったらグリッドを組み直し、新しい枠サイズで読み込み直す
        buildGrid();
        reloadVisibleFrames();
        if (isFullscreen()) loadImage(fullscreenView, (Uri) fullscreenView.getTag(), fullscreenMaxEdge());
    }

    @Override
    public void onBackPressed() {
        if (isFullscreen()) {
            exitFullscreen();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_ESCAPE && isFullscreen()) {
            exitFullscreen();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    // ------------------------------------------------------------------
    // 画面構成
    // ------------------------------------------------------------------

    private void buildViews() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        LinearLayout main = new LinearLayout(this);
        main.setOrientation(LinearLayout.VERTICAL);

        grid = new LinearLayout(this);
        grid.setOrientation(LinearLayout.VERTICAL);
        grid.setBackgroundColor(Color.rgb(40, 40, 40));
        grid.setOnLongClickListener(v -> {
            showMenu();
            return true;
        });
        main.addView(grid, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        statusView = new TextView(this);
        statusView.setTextColor(Color.rgb(190, 190, 190));
        statusView.setBackgroundColor(Color.rgb(20, 20, 20));
        statusView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        statusView.setSingleLine(true);
        int pad = dp(6);
        statusView.setPadding(pad * 2, pad, pad * 2, pad);
        statusView.setOnLongClickListener(v -> {
            showMenu();
            return true;
        });
        main.addView(statusView, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        root.addView(main, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        // 案内文（タッチは下の枠に通す）
        hintView = new TextView(this);
        hintView.setTextColor(Color.rgb(220, 220, 220));
        hintView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
        hintView.setGravity(Gravity.CENTER);
        hintView.setPadding(dp(32), 0, dp(32), 0);
        root.addView(hintView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        for (int i = 0; i < MAX_FRAMES; i++) {
            final int index = i;
            ImageView cell = new ImageView(this);
            cell.setScaleType(ImageView.ScaleType.FIT_CENTER);
            cell.setBackgroundColor(Color.BLACK);
            cell.setOnClickListener(v -> enterFullscreen(index));
            cell.setOnLongClickListener(v -> {
                showMenu();
                return true;
            });
            cells[i] = cell;
        }

        fullscreenView = new ImageView(this);
        fullscreenView.setScaleType(ImageView.ScaleType.FIT_CENTER);
        fullscreenView.setBackgroundColor(Color.BLACK);
        fullscreenView.setVisibility(View.GONE);
        fullscreenView.setOnClickListener(v -> exitFullscreen());
        root.addView(fullscreenView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        setContentView(root);
    }

    /** 表示枠数に応じた {行, 列}。縦向き画面では行と列を入れ替える。 */
    private int[] gridShape() {
        int rows;
        int cols;
        switch (frameCount) {
            case 1: rows = 1; cols = 1; break;
            case 2: rows = 1; cols = 2; break;
            case 3: rows = 1; cols = 3; break;
            case 4: rows = 2; cols = 2; break;
            default: rows = 2; cols = 3; break;
        }
        boolean portrait = getResources().getConfiguration().orientation
                == Configuration.ORIENTATION_PORTRAIT;
        return portrait ? new int[] {cols, rows} : new int[] {rows, cols};
    }

    private void buildGrid() {
        for (ImageView cell : cells) {
            ViewGroup parent = (ViewGroup) cell.getParent();
            if (parent != null) parent.removeView(cell);
        }
        grid.removeAllViews();

        int[] shape = gridShape();
        int rows = shape[0];
        int cols = shape[1];
        int gap = Math.max(1, dp(1));
        for (int r = 0; r < rows; r++) {
            LinearLayout row = new LinearLayout(this);
            row.setOrientation(LinearLayout.HORIZONTAL);
            for (int c = 0; c < cols; c++) {
                int index = r * cols + c;
                View child;
                if (index < frameCount) {
                    child = cells[index];
                } else {
                    // 5枠のときの空きマス
                    child = new View(this);
                    child.setBackgroundColor(Color.BLACK);
                    child.setOnLongClickListener(v -> {
                        showMenu();
                        return true;
                    });
                }
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                        0, ViewGroup.LayoutParams.MATCH_PARENT, 1f);
                lp.setMargins(gap, gap, gap, gap);
                row.addView(child, lp);
            }
            grid.addView(row, new LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        }
    }

    private void updateStatus() {
        String folder = treeUri == null ? "未選択" : folderName;
        String count = loadingFolder ? "読み込み中..." : media.size() + "枚";
        String slideshow = slideshowOn ? "ON（" + intervalSec + "秒）" : "OFF";
        statusView.setText("フォルダ: " + folder + "  |  画像: " + count
                + "  |  表示枠: " + frameCount + "  |  スライドショー: " + slideshow);

        if (treeUri == null) {
            hintView.setText("画面を長押しでメニューを開き、\n「フォルダ選択」で画像フォルダを指定してください");
            hintView.setVisibility(View.VISIBLE);
        } else if (!loadingFolder && media.isEmpty()) {
            hintView.setText("このフォルダには画像がありません\n（長押しでメニュー）");
            hintView.setVisibility(View.VISIBLE);
        } else {
            hintView.setVisibility(View.GONE);
        }
    }

    // ------------------------------------------------------------------
    // メニュー
    // ------------------------------------------------------------------

    /**
     * 長押しメニュー。PopupMenu は全画面（システムバー非表示）だと画面端に出て
     * 触れなくなることがあるため、画面中央に出るダイアログで表示する。
     */
    private void showMenu() {
        String[] items = {"フォルダ選択...", "表示", "スライドショー", "動画再生モード"};
        showCentered(new AlertDialog.Builder(this)
                .setTitle("メニュー（v" + versionName() + "）")
                .setItems(items, (d, which) -> {
                    switch (which) {
                        case 0: pickFolder(); break;
                        case 1: showViewMenu(); break;
                        case 2: showSlideshowMenu(); break;
                        default: startVideoMode(); break;
                    }
                }));
    }

    private void showViewMenu() {
        List<String> labels = new ArrayList<>();
        List<Runnable> actions = new ArrayList<>();
        if (frameCount < MAX_FRAMES) {
            labels.add("画像を追加（" + frameCount + " → " + (frameCount + 1) + "枠）");
            actions.add(() -> setFrameCount(frameCount + 1));
        }
        if (frameCount > MIN_FRAMES) {
            labels.add("画像を減らす（" + frameCount + " → " + (frameCount - 1) + "枠）");
            actions.add(() -> setFrameCount(frameCount - 1));
        }
        showActionDialog("表示", labels, actions);
    }

    private void showSlideshowMenu() {
        List<String> labels = new ArrayList<>();
        List<Runnable> actions = new ArrayList<>();
        labels.add(slideshowOn ? "✓ スライドショー ON（タップで OFF）" : "　 スライドショー ON");
        actions.add(() -> setSlideshow(!slideshowOn));
        labels.add("切り替え秒数を設定...（現在 " + intervalSec + "秒）");
        actions.add(this::showIntervalDialog);
        showActionDialog("スライドショー", labels, actions);
    }

    private void showActionDialog(String title, List<String> labels, List<Runnable> actions) {
        showCentered(new AlertDialog.Builder(this)
                .setTitle(title)
                .setItems(labels.toArray(new String[0]), (d, which) -> actions.get(which).run())
                .setNegativeButton("戻る", (d, w) -> showMenu()));
    }

    /** ダイアログを必ず画面中央に出す */
    private void showCentered(AlertDialog.Builder builder) {
        AlertDialog dialog = builder.create();
        dialog.show();
        if (dialog.getWindow() != null) dialog.getWindow().setGravity(Gravity.CENTER);
    }

    private String versionName() {
        try {
            return getPackageManager().getPackageInfo(getPackageName(), 0).versionName;
        } catch (PackageManager.NameNotFoundException e) {
            return "?";
        }
    }

    private void showIntervalDialog() {
        NumberPicker picker = new NumberPicker(this);
        picker.setMinValue(MIN_INTERVAL);
        picker.setMaxValue(MAX_INTERVAL);
        picker.setValue(intervalSec);
        picker.setWrapSelectorWheel(false);

        showCentered(new AlertDialog.Builder(this)
                .setTitle("切り替え秒数（" + MIN_INTERVAL + "〜" + MAX_INTERVAL + "秒）")
                .setView(picker)
                .setPositiveButton("OK", (d, w) -> {
                    picker.clearFocus();
                    intervalSec = picker.getValue();
                    prefs.edit().putInt(KEY_INTERVAL, intervalSec).apply();
                    updateSlideshow();
                    updateStatus();
                })
                .setNegativeButton("キャンセル", null));
    }

    // ------------------------------------------------------------------
    // 表示枠・スライドショー
    // ------------------------------------------------------------------

    private void setFrameCount(int count) {
        count = clamp(count, MIN_FRAMES, MAX_FRAMES);
        if (count == frameCount) return;
        int old = frameCount;
        frameCount = count;
        prefs.edit().putInt(KEY_FRAMES, frameCount).apply();

        // 減らした枠は空にする
        for (int i = count; i < old; i++) {
            shown[i] = null;
            cells[i].setTag(null);
            cells[i].setImageDrawable(null);
        }
        // 増やした枠には今表示していない画像を割り当てる
        for (int i = old; i < count; i++) {
            Uri[] picked = pickRandom(1, currentlyShown());
            shown[i] = picked[0];
        }

        buildGrid();
        reloadVisibleFrames();
        updateStatus();
    }

    private void setSlideshow(boolean on) {
        slideshowOn = on;
        prefs.edit().putBoolean(KEY_SLIDESHOW, on).apply();
        updateSlideshow();
        updateStatus();
    }

    private void updateSlideshow() {
        handler.removeCallbacks(slideshowTick);
        boolean running = slideshowOn && resumed && !media.isEmpty();
        if (running) handler.postDelayed(slideshowTick, intervalSec * 1000L);

        if (slideshowOn) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    }

    /** 全枠を同時に新しいランダム画像へ切り替える（全画面中の画像はそのまま） */
    private void showRandomInAllFrames() {
        Uri[] picked = pickRandom(frameCount, currentlyShown());
        System.arraycopy(picked, 0, shown, 0, frameCount);
        reloadVisibleFrames();
    }

    private void reloadVisibleFrames() {
        int maxEdge = gridMaxEdge();
        for (int i = 0; i < frameCount; i++) {
            if (shown[i] == null) {
                cells[i].setTag(null);
                cells[i].setImageDrawable(null);
            } else if (!shown[i].equals(cells[i].getTag()) || cells[i].getDrawable() == null
                    || !Integer.valueOf(maxEdge).equals(cells[i].getTag(R.id.decoded_edge_tag))) {
                loadImage(cells[i], shown[i], maxEdge);
            }
        }
    }

    private List<Uri> currentlyShown() {
        List<Uri> list = new ArrayList<>();
        for (int i = 0; i < frameCount; i++) {
            if (shown[i] != null) list.add(shown[i]);
        }
        return list;
    }

    /**
     * なるべく重複せず、avoid に含まれない画像を n 枚選ぶ。
     * 候補が足りなくなったら重複を許す。
     */
    private Uri[] pickRandom(int n, Collection<Uri> avoid) {
        Uri[] out = new Uri[n];
        int size = media.size();
        if (size == 0) return out;
        Set<Uri> used = new HashSet<>(avoid);
        for (int i = 0; i < n; i++) {
            if (used.size() >= size) used.clear();
            Uri uri;
            do {
                uri = media.get(random.nextInt(size));
            } while (used.contains(uri));
            used.add(uri);
            out[i] = uri;
        }
        return out;
    }

    // ------------------------------------------------------------------
    // 全画面表示
    // ------------------------------------------------------------------

    private boolean isFullscreen() {
        return fullscreenView.getVisibility() == View.VISIBLE;
    }

    private void enterFullscreen(int index) {
        Uri uri = shown[index];
        if (uri == null) return;
        // まず枠の画像をそのまま出し、高解像度版を読み込み直す
        Drawable current = cells[index].getDrawable();
        if (current instanceof BitmapDrawable) {
            fullscreenView.setImageBitmap(((BitmapDrawable) current).getBitmap());
        } else {
            fullscreenView.setImageDrawable(null);
        }
        fullscreenView.setVisibility(View.VISIBLE);
        loadImage(fullscreenView, uri, fullscreenMaxEdge());
    }

    private void exitFullscreen() {
        fullscreenView.setVisibility(View.GONE);
        fullscreenView.setTag(null);
        fullscreenView.setImageDrawable(null);
    }

    // ------------------------------------------------------------------
    // フォルダ選択・読み込み
    // ------------------------------------------------------------------

    private void pickFolder() {
        openFolderPicker(REQ_PICK_FOLDER, treeUri);
    }

    private void openFolderPicker(int requestCode, Uri initialTree) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        if (initialTree != null) {
            // 前回のフォルダから開く
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUriUsingTree(
                            initialTree, DocumentsContract.getTreeDocumentId(initialTree)));
        }
        try {
            startActivityForResult(intent, requestCode);
        } catch (RuntimeException e) {
            toast("フォルダ選択画面を開けませんでした");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_PICK_FOLDER && requestCode != REQ_PICK_VIDEO_FOLDER) return;
        if (resultCode != RESULT_OK || data == null) return;
        Uri uri = data.getData();
        if (uri == null) return;

        ContentResolver resolver = getContentResolver();
        try {
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (SecurityException e) {
            toast("フォルダへのアクセス許可を取得できませんでした");
            return;
        }
        if (requestCode == REQ_PICK_VIDEO_FOLDER) {
            prefs.edit().putString(KEY_VIDEO_TREE_URI, uri.toString()).apply();
            releaseUnusedPermissions();
            showVideoChooser(uri);
        } else {
            prefs.edit().putString(KEY_TREE_URI, uri.toString()).apply();
            releaseUnusedPermissions();
            loadFolder(uri);
        }
    }

    /** 画像フォルダ・動画フォルダのどちらでもなくなったフォルダの許可を手放す */
    private void releaseUnusedPermissions() {
        Set<String> inUse = new HashSet<>();
        inUse.add(prefs.getString(KEY_TREE_URI, ""));
        inUse.add(prefs.getString(KEY_VIDEO_TREE_URI, ""));
        ContentResolver resolver = getContentResolver();
        for (UriPermission p : resolver.getPersistedUriPermissions()) {
            if (!inUse.contains(p.getUri().toString())) {
                try {
                    resolver.releasePersistableUriPermission(
                            p.getUri(), Intent.FLAG_GRANT_READ_URI_PERMISSION);
                } catch (SecurityException ignored) {
                    // 既に失効している
                }
            }
        }
    }

    private boolean hasPersistedPermission(Uri uri) {
        for (UriPermission p : getContentResolver().getPersistedUriPermissions()) {
            if (p.getUri().equals(uri) && p.isReadPermission()) return true;
        }
        return false;
    }

    private void loadFolder(Uri tree) {
        treeUri = tree;
        folderName = "";
        loadingFolder = true;
        final int generation = ++folderGeneration;
        updateStatus();

        executor.execute(() -> {
            String name = FolderScanner.folderName(getContentResolver(), tree);
            List<Uri> found;
            String error = null;
            try {
                found = new ArrayList<>();
                for (FolderScanner.Item item
                        : FolderScanner.list(getContentResolver(), tree, "image/")) {
                    found.add(item.uri);
                }
            } catch (RuntimeException e) {
                found = new ArrayList<>();
                error = "フォルダを読み込めませんでした";
            }
            final List<Uri> result = found;
            final String message = error;
            handler.post(() -> {
                if (generation != folderGeneration) return;
                loadingFolder = false;
                folderName = name;
                media = result;
                if (message != null) toast(message);
                onFolderLoaded();
            });
        });
    }

    private void onFolderLoaded() {
        Arrays.fill(shown, null);
        Uri[] picked = pickRandom(frameCount, new ArrayList<>());
        System.arraycopy(picked, 0, shown, 0, frameCount);
        exitFullscreen();
        reloadVisibleFrames();
        updateSlideshow();
        updateStatus();
    }

    // ------------------------------------------------------------------
    // 動画再生モード
    // ------------------------------------------------------------------

    /** 前回の動画フォルダが使えればその中から選ばせ、なければフォルダ選択を開く */
    private void startVideoMode() {
        String saved = prefs.getString(KEY_VIDEO_TREE_URI, null);
        Uri tree = saved == null ? null : Uri.parse(saved);
        if (tree != null && hasPersistedPermission(tree)) {
            showVideoChooser(tree);
        } else {
            openFolderPicker(REQ_PICK_VIDEO_FOLDER, tree != null ? tree : treeUri);
        }
    }

    private void showVideoChooser(Uri tree) {
        Toast loading = Toast.makeText(this, "動画を探しています...", Toast.LENGTH_SHORT);
        loading.show();
        executor.execute(() -> {
            String name = FolderScanner.folderName(getContentResolver(), tree);
            List<FolderScanner.Item> videos;
            try {
                videos = FolderScanner.list(getContentResolver(), tree, "video/");
            } catch (RuntimeException e) {
                videos = null;
            }
            final List<FolderScanner.Item> result = videos;
            handler.post(() -> {
                loading.cancel();
                if (isFinishing() || isDestroyed()) return;
                showVideoChooserDialog(tree, name, result);
            });
        });
    }

    private void showVideoChooserDialog(Uri tree, String name, List<FolderScanner.Item> videos) {
        AlertDialog.Builder builder = new AlertDialog.Builder(this)
                .setNeutralButton("別のフォルダ...",
                        (d, w) -> openFolderPicker(REQ_PICK_VIDEO_FOLDER, tree))
                .setNegativeButton("キャンセル", null);
        if (videos == null || videos.isEmpty()) {
            builder.setTitle(name)
                    .setMessage(videos == null
                            ? "フォルダを読み込めませんでした"
                            : "このフォルダには動画がありません");
        } else {
            String[] names = new String[videos.size()];
            for (int i = 0; i < names.length; i++) names[i] = videos.get(i).name;
            builder.setTitle("再生する動画を選択（" + name + "）")
                    .setItems(names, (d, which) -> {
                        Intent intent = new Intent(this, VideoActivity.class);
                        intent.putExtra(VideoActivity.EXTRA_TREE_URI, tree.toString());
                        intent.setData(videos.get(which).uri);
                        startActivity(intent);
                    });
        }
        showCentered(builder);
    }

    // ------------------------------------------------------------------
    // 画像読み込み
    // ------------------------------------------------------------------

    private int gridMaxEdge() {
        int[] shape = gridShape();
        DisplayMetrics dm = getResources().getDisplayMetrics();
        return Math.max(dm.widthPixels / shape[1], dm.heightPixels / shape[0]);
    }

    private int fullscreenMaxEdge() {
        DisplayMetrics dm = getResources().getDisplayMetrics();
        return Math.max(dm.widthPixels, dm.heightPixels);
    }

    /** 画像を別スレッドで縮小デコードし、view がまだ同じ画像を待っていれば表示する */
    private void loadImage(ImageView view, Uri uri, int maxEdge) {
        view.setTag(uri);
        if (uri == null) {
            view.setImageDrawable(null);
            return;
        }
        executor.execute(() -> {
            Bitmap bitmap = decode(uri, maxEdge);
            handler.post(() -> {
                if (!uri.equals(view.getTag())) return;
                view.setImageBitmap(bitmap);
                view.setTag(R.id.decoded_edge_tag, maxEdge);
            });
        });
    }

    private Bitmap decode(Uri uri, int maxEdge) {
        try {
            ImageDecoder.Source source = ImageDecoder.createSource(getContentResolver(), uri);
            return ImageDecoder.decodeBitmap(source, (decoder, info, src) -> {
                int w = info.getSize().getWidth();
                int h = info.getSize().getHeight();
                int longEdge = Math.max(w, h);
                if (longEdge > maxEdge) {
                    float scale = (float) maxEdge / longEdge;
                    decoder.setTargetSize(
                            Math.max(1, Math.round(w * scale)),
                            Math.max(1, Math.round(h * scale)));
                }
            });
        } catch (Exception | OutOfMemoryError e) {
            return null;
        }
    }

    // ------------------------------------------------------------------
    // ユーティリティ
    // ------------------------------------------------------------------

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private static int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
