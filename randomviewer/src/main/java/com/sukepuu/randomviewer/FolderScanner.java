package com.sukepuu.randomviewer;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;

import java.util.ArrayList;
import java.util.List;

/** ストレージアクセスフレームワークで選んだフォルダの中身を調べる */
final class FolderScanner {

    static final class Item {
        final Uri uri;
        final String name;

        Item(Uri uri, String name) {
            this.uri = uri;
            this.name = name;
        }
    }

    private FolderScanner() {
    }

    /** フォルダ直下で MIME タイプが prefix（"image/" など）で始まるファイルを名前順に返す */
    static List<Item> list(ContentResolver resolver, Uri tree, String mimePrefix) {
        List<Item> result = new ArrayList<>();
        Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(
                tree, DocumentsContract.getTreeDocumentId(tree));
        try (Cursor c = resolver.query(children,
                new String[] {
                        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                        DocumentsContract.Document.COLUMN_MIME_TYPE,
                        DocumentsContract.Document.COLUMN_DISPLAY_NAME
                },
                null, null, null)) {
            if (c == null) return result;
            while (c.moveToNext()) {
                String id = c.getString(0);
                String mime = c.getString(1);
                String name = c.getString(2);
                if (id != null && mime != null && mime.startsWith(mimePrefix)) {
                    result.add(new Item(DocumentsContract.buildDocumentUriUsingTree(tree, id),
                            name != null ? name : id));
                }
            }
        }
        result.sort((a, b) -> a.name.compareToIgnoreCase(b.name));
        return result;
    }

    static String folderName(ContentResolver resolver, Uri tree) {
        Uri doc = DocumentsContract.buildDocumentUriUsingTree(
                tree, DocumentsContract.getTreeDocumentId(tree));
        try (Cursor c = resolver.query(doc,
                new String[] {DocumentsContract.Document.COLUMN_DISPLAY_NAME},
                null, null, null)) {
            if (c != null && c.moveToFirst()) {
                String name = c.getString(0);
                if (name != null) return name;
            }
        } catch (RuntimeException ignored) {
            // 名前が取れなくても表示に支障はない
        }
        return tree.getLastPathSegment();
    }
}
