package com.carriez.flutter_hbb

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.File

/**
 * Storage Access Framework (SAF) 辅助类
 * 用于替代 MANAGE_EXTERNAL_STORAGE 权限
 * 提供安全的文件访问方式
 */
class StorageAccessFrameworkHelper(private val context: Context) {

    companion object {
        private const val TAG = "SAFHelper"
        const val REQUEST_CODE_PICK_FILE = 10001
        const val REQUEST_CODE_PICK_MULTIPLE_FILES = 10002
        const val REQUEST_CODE_PICK_DIRECTORY = 10003
        const val REQUEST_CODE_CREATE_FILE = 10004
    }

    /**
     * 打开单个文件选择器
     */
    fun openFilePicker(activity: Activity, mimeType: String = "*/*") {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
    }

    /**
     * 打开多文件选择器
     */
    fun openMultipleFilePicker(activity: Activity, mimeType: String = "*/*") {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_MULTIPLE_FILES)
    }

    /**
     * 打开目录选择器
     */
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun openDirectoryPicker(activity: Activity) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_PICK_DIRECTORY)
    }

    /**
     * 创建文件选择器
     */
    fun openCreateFilePicker(activity: Activity, mimeType: String = "*/*", fileName: String = "file") {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        activity.startActivityForResult(intent, REQUEST_CODE_CREATE_FILE)
    }

    /**
     * 获取持久化权限
     */
    fun takePersistableUriPermission(uri: Uri, modeFlags: Int) {
        try {
            context.contentResolver.takePersistableUriPermission(uri, modeFlags)
            Log.d(TAG, "Persistable permission taken for: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to take persistable permission: ${e.message}")
        }
    }

    /**
     * 释放持久化权限
     */
    fun releasePersistableUriPermission(uri: Uri, modeFlags: Int) {
        try {
            context.contentResolver.releasePersistableUriPermission(uri, modeFlags)
            Log.d(TAG, "Persistable permission released for: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release persistable permission: ${e.message}")
        }
    }

    /**
     * 获取应用专属下载目录
     * 这是推荐的文件存储位置，不需要特殊权限
     */
    fun getAppDownloadDirectory(): File {
        val dir = File(context.getExternalFilesDir(android.os.Environment.DIRECTORY_DOWNLOADS), "RustDesk")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * 获取应用专属缓存目录
     */
    fun getAppCacheDirectory(): File {
        val dir = File(context.externalCacheDir, "transfers")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir
    }

    /**
     * 获取应用专属文件目录
     */
    fun getAppFilesDirectory(): File {
        return context.filesDir
    }

    /**
     * 检查 URI 是否有持久化权限
     */
    fun hasPersistablePermission(uri: Uri): Boolean {
        val persistedUris = context.contentResolver.persistedUriPermissions
        return persistedUris.any { it.uri == uri }
    }

    /**
     * 获取文件名从 URI
     */
    fun getFileName(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            val cursor = context.contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        result = it.getString(nameIndex)
                    }
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/')
            if (cut != -1) {
                result = result?.substring(cut!! + 1)
            }
        }
        return result
    }

    /**
     * 处理 onActivityResult 结果
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?, callback: (SAFResult) -&gt; Unit) {
        if (resultCode != Activity.RESULT_OK) {
            callback(SAFResult.Cancelled)
            return
        }

        when (requestCode) {
            REQUEST_CODE_PICK_FILE -&gt; {
                data?.data?.let { uri -&gt;
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    callback(SAFResult.FilePicked(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            REQUEST_CODE_PICK_MULTIPLE_FILES -&gt; {
                val uris = mutableListOf&lt;Uri&gt;()
                data?.clipData?.let { clipData -&gt;
                    for (i in 0 until clipData.itemCount) {
                        val uri = clipData.getItemAt(i).uri
                        takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        uris.add(uri)
                    }
                } ?: data?.data?.let { uri -&gt;
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    uris.add(uri)
                }
                if (uris.isNotEmpty()) {
                    callback(SAFResult.MultipleFilesPicked(uris))
                } else {
                    callback(SAFResult.Failed("No URIs returned"))
                }
            }
            REQUEST_CODE_PICK_DIRECTORY -&gt; {
                data?.data?.let { uri -&gt;
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    takePersistableUriPermission(uri, flags)
                    callback(SAFResult.DirectoryPicked(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            REQUEST_CODE_CREATE_FILE -&gt; {
                data?.data?.let { uri -&gt;
                    takePersistableUriPermission(uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    callback(SAFResult.FileCreated(uri))
                } ?: callback(SAFResult.Failed("No URI returned"))
            }
            else -&gt; {
                callback(SAFResult.UnknownRequestCode)
            }
        }
    }

    /**
     * SAF 操作结果
     */
    sealed class SAFResult {
        object Cancelled : SAFResult()
        object UnknownRequestCode : SAFResult()
        data class Failed(val message: String) : SAFResult()
        data class FilePicked(val uri: Uri) : SAFResult()
        data class MultipleFilesPicked(val uris: List&lt;Uri&gt;) : SAFResult()
        data class DirectoryPicked(val uri: Uri) : SAFResult()
        data class FileCreated(val uri: Uri) : SAFResult()
    }
}
