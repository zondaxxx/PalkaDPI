package io.github.dovecoteescapee.byedpi.activities

import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.FragmentManager
import io.github.dovecoteescapee.byedpi.BuildConfig
import io.github.dovecoteescapee.byedpi.R
import io.github.dovecoteescapee.byedpi.fragments.MainSettingsFragment
import io.github.dovecoteescapee.byedpi.utility.getPreferences
import org.json.JSONObject

class SettingsActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        supportFragmentManager
            .beginTransaction()
            .replace(R.id.settings, MainSettingsFragment())
            .commit()

        supportActionBar?.setDisplayHomeAsUpEnabled(true)
    }

    override fun onCreateOptionsMenu(menu: Menu?): Boolean {
        menuInflater.inflate(R.menu.menu_settings, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        android.R.id.home -> {
            onBackPressedDispatcher.onBackPressed()
            true
        }

        R.id.action_reset_settings -> {
            val prefs = getPreferences()
            val currentLanguage = prefs.getString("language", "system")
            val editor = prefs.edit()

            editor.clear()
            editor.putString("language", currentLanguage)
            editor.apply()

            supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)
            supportFragmentManager
                .beginTransaction()
                .replace(R.id.settings, MainSettingsFragment())
                .commit()
            true
        }

        R.id.action_export_settings -> {
            val fileName = "bbd_${System.currentTimeMillis().toReadableDateTime()}.json"
            exportSettingsLauncher.launch(fileName)
            true
        }

        R.id.action_import_settings -> {
            importSettingsLauncher.launch(arrayOf("application/json"))
            true
        }

        else -> super.onOptionsItemSelected(item)
    }

    private val exportSettingsLauncher = registerForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        uri?.let {
            val prefs = getPreferences()
            val json = JSONObject()

            json.put("app_package", BuildConfig.APPLICATION_ID)
            json.put("app_version", BuildConfig.VERSION_NAME)

            prefs.all.forEach { (key, value) ->
                json.put(key, value)
            }

            contentResolver.openOutputStream(it)?.use { outputStream ->
                outputStream.write(json.toString().toByteArray())
            }
        }
    }

    private val importSettingsLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let {
            contentResolver.openInputStream(it)?.use { inputStream ->
                val json = JSONObject(inputStream.bufferedReader().readText())

                if (json.optString("app_package", "") != BuildConfig.APPLICATION_ID) {
                    Toast.makeText(this, "Invalid config", Toast.LENGTH_LONG).show()
                    return@use
                }

                val prefs = getPreferences()
                val editor = prefs.edit()

                json.remove("app_package")
                json.remove("app_version")

                json.keys().forEach { key ->
                    when (val value = json.get(key)) {
                        is Int -> editor.putInt(key, value)
                        is Boolean -> editor.putBoolean(key, value)
                        is String -> editor.putString(key, value)
                        is Float -> editor.putFloat(key, value)
                        is Long -> editor.putLong(key, value)
                    }
                }

                editor.apply()

                supportFragmentManager.popBackStack(null, FragmentManager.POP_BACK_STACK_INCLUSIVE)
                supportFragmentManager
                    .beginTransaction()
                    .replace(R.id.settings, MainSettingsFragment())
                    .commit()
            }
        }
    }

    private fun Long.toReadableDateTime(): String {
        val format = java.text.SimpleDateFormat("yyyyMMdd_HHmm", java.util.Locale.getDefault())
        return format.format(this)
    }
}