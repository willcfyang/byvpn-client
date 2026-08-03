package net.nymtech.nymvpn.util

import android.content.Context
import android.system.ErrnoException
import android.system.Os
import net.nymtech.nymvpn.BuildConfig
import timber.log.Timber
import java.io.File

/** Seeds vpn.sf mock network discovery into app storage for internal lab APK builds. */
object LabMockBootstrap {
	private const val TAG = "lab-mock-bootstrap"
	private val ASSET_FILES = listOf("mainnet_discovery.json", "mainnet.json")

	/**
	 * Colocated mock lab: WG registration can succeed while the default 1.1.1.1 probe never
	 * returns (NAT / CN network). Match host scripts (`NYM_VPN_LAB_SKIP_CONNECTION_PROBE=1`).
	 */
	fun setLabEnvironment() {
		if (!BuildConfig.LAB_MOCK) return
		runCatching {
			Os.setenv("NYM_VPN_LAB_SKIP_CONNECTION_PROBE", "1", true)
			Os.setenv("NYM_VPN_LAB_PROBE_IP", "104.250.122.199", true)
			Timber.tag(TAG).i("LabMockEnv skip_probe=1 probe_ip=104.250.122.199")
		}.onFailure { t ->
			val message = when (t) {
				is ErrnoException -> "errno=${t.errno} ${t.message}"
				else -> t.message
			}
			Timber.tag(TAG).w("LabMockEnvFailed: $message")
		}
	}

	fun installNetworkConfig(context: Context) {
		if (!BuildConfig.LAB_MOCK) return

		val destDir = File(context.filesDir, "networks/mainnet").apply { mkdirs() }
		for (name in ASSET_FILES) {
			val dest = File(destDir, name)
			context.assets.open("nym/networks/mainnet/$name").use { input ->
				dest.outputStream().use { output -> input.copyTo(output) }
			}
			Timber.tag(TAG).i("Installed %s -> %s", name, dest.absolutePath)
		}
	}
}
