package com.sukepuu.randomviewer;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.media.MediaPlayer;
import android.media.PlaybackParams;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.NumberPicker;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.VideoView;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * 動画再生モード。選んだ動画から再生を始め、同じフォルダの動画を順番（またはシャッフル）に再生する。
 * 画面タップで中央下に操作ボタンを表示、左右スワイプで前/次の動画へ移動する。
 */
public class VideoActivity extends Activity {

    /** 再生する動画が入っているフォルダ（ツリー URI の文字列）。開始する動画は Intent の data で渡す。 */
    static final String EXTRA_TREE_URI = "treeUri";

    private static final String PREFS = "settings";
    private static final String KEY_SPEED = "videoSpeedTenths";
    private static final String KEY_LOOP = "videoLoop";
    private static final String KEY_SHUFFLE = "videoShuffle";

    /** 再生速度は 0.1 倍刻みで 0.1〜2.0 倍（10 倍した整数で持つ） */
    private static final int MIN_SPEED_TENTHS = 1;
    private static final int MAX_SPEED_TENTHS = 20;
    private static final long CONTROLS_TIMEOUT_MS = 4000;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private SharedPreferences prefs;
    private VideoView videoView;
    private LinearLayout controls;
    private TextView titleView;
    private TextView playPauseButton;
    private TextView speedButton;
    private TextView loopButton;
    private TextView shuffleButton;

    private List<FolderScanner.Item> videos = new ArrayList<>();
    /** 再生順（videos のインデックス）。シャッフル ON のときは並び替えたもの */
    private List<Integer> order = new ArrayList<>();
    private int orderPos;

    private MediaPlayer player;
    private int speedTenths = 10;
    private boolean loop;
    private boolean shuffle;
    /** ユーザーが停止ボタンで止めているか */
    private boolean userPaused;
    /** 画面を離れたときの再生位置（戻ってきたら続きから） */
    private int resumePosition = -1;

    private final Runnable hideControls = () -> controls.setVisibility(View.GONE);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        speedTenths = Math.max(MIN_SPEED_TENTHS,
                Math.min(MAX_SPEED_TENTHS, prefs.getInt(KEY_SPEED, 10)));
        loop = prefs.getBoolean(KEY_LOOP, false);
        shuffle = prefs.getBoolean(KEY_SHUFFLE, false);

        buildViews();
        updateButtons();

        String treeString = getIntent().getStringExtra(EXTRA_TREE_URI);
        Uri startUri = getIntent().getData();
        if (treeString == null || startUri == null) {
            finish();
            return;
        }
        Uri tree = Uri.parse(treeString);
        executor.execute(() -> {
            List<FolderScanner.Item> found;
            try {
                found = FolderScanner.list(getContentResolver(), tree, "video/");
            } catch (RuntimeException e) {
                found = new ArrayList<>();
            }
            final List<FolderScanner.Item> result = found;
            handler.post(() -> onVideosLoaded(result, startUri));
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (resumePosition >= 0) {
            videoView.seekTo(resumePosition);
            resumePosition = -1;
            if (!userPaused) videoView.start();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (!videos.isEmpty()) {
            resumePosition = videoView.getCurrentPosition();
            videoView.pause();
        }
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        executor.shutdownNow();
        videoView.stopPlayback();
        super.onDestroy();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) SystemBars.hide(getWindow());
    }

    // ------------------------------------------------------------------
    // 画面構成
    // ------------------------------------------------------------------

    private void buildViews() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        videoView = new VideoView(this);
        videoView.setOnPreparedListener(this::onPrepared);
        videoView.setOnCompletionListener(mp -> {
            // ループ OFF のときだけ呼ばれる（ON なら MediaPlayer 側で繰り返す）
            if (!loop) playNext();
        });
        videoView.setOnErrorListener((mp, what, extra) -> {
            toast("この動画は再生できません: " + currentItemName());
            showControls();
            return true;
        });
        root.addView(videoView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER));

        // タップとスワイプを受け取る透明なレイヤー
        View touchLayer = new View(this);
        GestureDetector detector = new GestureDetector(this,
                new GestureDetector.SimpleOnGestureListener() {
                    @Override
                    public boolean onDown(MotionEvent e) {
                        return true;
                    }

                    @Override
                    public boolean onSingleTapConfirmed(MotionEvent e) {
                        toggleControls();
                        return true;
                    }

                    @Override
                    public boolean onFling(MotionEvent e1, MotionEvent e2, float vx, float vy) {
                        if (e1 == null) return false;
                        float dx = e2.getX() - e1.getX();
                        float dy = e2.getY() - e1.getY();
                        if (Math.abs(dx) < dp(60) || Math.abs(dx) < Math.abs(dy)) return false;
                        if (dx < 0) {
                            playNext();
                        } else {
                            playPrevious();
                        }
                        return true;
                    }
                });
        touchLayer.setOnTouchListener((v, event) -> detector.onTouchEvent(event));
        root.addView(touchLayer, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        // 中央下の操作パネル
        controls = new LinearLayout(this);
        controls.setOrientation(LinearLayout.VERTICAL);
        controls.setGravity(Gravity.CENTER_HORIZONTAL);
        int pad = dp(10);
        controls.setPadding(pad, pad, pad, pad);
        GradientDrawable panel = new GradientDrawable();
        panel.setColor(Color.argb(170, 0, 0, 0));
        panel.setCornerRadius(dp(16));
        controls.setBackground(panel);
        controls.setClickable(true); // パネルの隙間のタップを下に通さない

        titleView = new TextView(this);
        titleView.setTextColor(Color.WHITE);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        titleView.setSingleLine(true);
        titleView.setGravity(Gravity.CENTER);
        titleView.setPadding(dp(8), 0, dp(8), dp(6));
        controls.addView(titleView, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout row1 = new LinearLayout(this);
        row1.addView(makeButton("⏮ 前へ", 18, v -> playPrevious()));
        playPauseButton = makeButton("", 18, v -> togglePause());
        row1.addView(playPauseButton);
        row1.addView(makeButton("次へ ⏭", 18, v -> playNext()));
        controls.addView(row1);

        LinearLayout row2 = new LinearLayout(this);
        speedButton = makeButton("", 14, v -> showSpeedDialog());
        row2.addView(speedButton);
        loopButton = makeButton("", 14, v -> setLoop(!loop));
        row2.addView(loopButton);
        shuffleButton = makeButton("", 14, v -> setShuffle(!shuffle));
        row2.addView(shuffleButton);
        controls.addView(row2);

        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        lp.bottomMargin = dp(32);
        lp.leftMargin = dp(8);
        lp.rightMargin = dp(8);
        root.addView(controls, lp);
        controls.setVisibility(View.GONE);

        setContentView(root);
    }

    private TextView makeButton(String text, int textSp, View.OnClickListener onClick) {
        TextView button = new TextView(this);
        button.setText(text);
        button.setTextColor(Color.WHITE);
        button.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSp);
        button.setGravity(Gravity.CENTER);
        button.setPadding(dp(14), dp(10), dp(14), dp(10));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(Color.argb(60, 255, 255, 255));
        bg.setCornerRadius(dp(10));
        button.setBackground(bg);
        button.setOnClickListener(v -> {
            onClick.onClick(v);
            scheduleHideControls();
        });
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(dp(4), dp(4), dp(4), dp(4));
        button.setLayoutParams(lp);
        return button;
    }

    private void updateButtons() {
        playPauseButton.setText(userPaused ? "▶ 再開" : "⏸ 停止");
        speedButton.setText(String.format(Locale.US, "速度 %.1fx", speedTenths / 10f));
        loopButton.setText(loop ? "🔁 ループ ON" : "🔁 ループ OFF");
        shuffleButton.setText(shuffle ? "🔀 シャッフル ON" : "🔀 シャッフル OFF");
        loopButton.setAlpha(loop ? 1f : 0.55f);
        shuffleButton.setAlpha(shuffle ? 1f : 0.55f);
        if (!order.isEmpty()) {
            titleView.setText(currentItemName() + "  (" + (order.get(orderPos) + 1)
                    + "/" + videos.size() + ")");
        }
    }

    private void toggleControls() {
        if (controls.getVisibility() == View.VISIBLE) {
            handler.removeCallbacks(hideControls);
            controls.setVisibility(View.GONE);
        } else {
            showControls();
        }
    }

    private void showControls() {
        controls.setVisibility(View.VISIBLE);
        scheduleHideControls();
    }

    /** 再生中は一定時間操作がなければボタンを隠す（停止中は出したまま） */
    private void scheduleHideControls() {
        handler.removeCallbacks(hideControls);
        if (!userPaused) handler.postDelayed(hideControls, CONTROLS_TIMEOUT_MS);
    }

    // ------------------------------------------------------------------
    // 再生リスト
    // ------------------------------------------------------------------

    private void onVideosLoaded(List<FolderScanner.Item> found, Uri startUri) {
        if (isFinishing() || isDestroyed()) return;
        if (found.isEmpty()) {
            toast("動画を読み込めませんでした");
            finish();
            return;
        }
        videos = found;
        int start = 0;
        for (int i = 0; i < videos.size(); i++) {
            if (videos.get(i).uri.equals(startUri)) {
                start = i;
                break;
            }
        }
        buildOrder(start);
        playCurrent();
        showControls();
    }

    /** 再生順を作り直す。current の動画が再生順の現在位置になる */
    private void buildOrder(int current) {
        order = new ArrayList<>();
        if (shuffle) {
            for (int i = 0; i < videos.size(); i++) {
                if (i != current) order.add(i);
            }
            Collections.shuffle(order);
            order.add(0, current);
            orderPos = 0;
        } else {
            for (int i = 0; i < videos.size(); i++) order.add(i);
            orderPos = current;
        }
    }

    private int currentIndex() {
        return order.get(orderPos);
    }

    private String currentItemName() {
        return order.isEmpty() ? "" : videos.get(currentIndex()).name;
    }

    private void playNext() {
        if (order.isEmpty()) return;
        if (orderPos + 1 < order.size()) {
            orderPos++;
        } else if (shuffle && order.size() > 1) {
            // 一巡したら並びを作り直す（今の動画が続けて流れないよう先頭に置いて次へ進む）
            buildOrder(currentIndex());
            orderPos = 1;
        } else {
            orderPos = 0;
        }
        playCurrent();
    }

    private void playPrevious() {
        if (order.isEmpty()) return;
        orderPos = (orderPos - 1 + order.size()) % order.size();
        playCurrent();
    }

    private void playCurrent() {
        player = null;
        userPaused = false;
        videoView.setVideoURI(videos.get(currentIndex()).uri);
        videoView.start();
        updateButtons();
        if (controls.getVisibility() == View.VISIBLE) scheduleHideControls();
    }

    // ------------------------------------------------------------------
    // 再生操作
    // ------------------------------------------------------------------

    private void onPrepared(MediaPlayer mp) {
        player = mp;
        mp.setLooping(loop);
        applySpeed();
    }

    private void togglePause() {
        if (order.isEmpty()) return;
        if (userPaused) {
            userPaused = false;
            videoView.start();
            applySpeed();
        } else {
            userPaused = true;
            videoView.pause();
        }
        updateButtons();
    }

    /** 再生速度を反映する。停止中に速度を設定すると再生が始まってしまうので、再開時に反映する */
    private void applySpeed() {
        if (player == null || userPaused) return;
        try {
            PlaybackParams params = player.getPlaybackParams();
            player.setPlaybackParams(params.setSpeed(speedTenths / 10f));
        } catch (IllegalStateException | IllegalArgumentException e) {
            toast("この動画では再生速度を変更できません");
        }
    }

    private void showSpeedDialog() {
        handler.removeCallbacks(hideControls);
        String[] labels = new String[MAX_SPEED_TENTHS - MIN_SPEED_TENTHS + 1];
        for (int i = 0; i < labels.length; i++) {
            labels[i] = String.format(Locale.US, "%.1fx", (MIN_SPEED_TENTHS + i) / 10f);
        }
        NumberPicker picker = new NumberPicker(this);
        picker.setMinValue(MIN_SPEED_TENTHS);
        picker.setMaxValue(MAX_SPEED_TENTHS);
        picker.setDisplayedValues(labels);
        picker.setValue(speedTenths);
        picker.setWrapSelectorWheel(false);

        new AlertDialog.Builder(this)
                .setTitle("再生速度（0.1〜2.0倍）")
                .setView(picker)
                .setPositiveButton("OK", (d, w) -> {
                    picker.clearFocus();
                    speedTenths = picker.getValue();
                    prefs.edit().putInt(KEY_SPEED, speedTenths).apply();
                    applySpeed();
                    updateButtons();
                })
                .setNeutralButton("1.0x に戻す", (d, w) -> {
                    speedTenths = 10;
                    prefs.edit().putInt(KEY_SPEED, speedTenths).apply();
                    applySpeed();
                    updateButtons();
                })
                .setNegativeButton("キャンセル", null)
                .setOnDismissListener(d -> scheduleHideControls())
                .show();
    }

    private void setLoop(boolean on) {
        loop = on;
        prefs.edit().putBoolean(KEY_LOOP, on).apply();
        if (player != null) {
            try {
                player.setLooping(on);
            } catch (IllegalStateException ignored) {
                // 次の動画の準備完了時に反映される
            }
        }
        updateButtons();
    }

    private void setShuffle(boolean on) {
        shuffle = on;
        prefs.edit().putBoolean(KEY_SHUFFLE, on).apply();
        if (!order.isEmpty()) buildOrder(currentIndex());
        updateButtons();
    }

    // ------------------------------------------------------------------
    // ユーティリティ
    // ------------------------------------------------------------------

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }
}
