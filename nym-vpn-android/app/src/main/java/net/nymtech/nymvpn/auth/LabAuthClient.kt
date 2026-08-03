package net.nymtech.nymvpn.auth

import android.util.Log
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import net.nymtech.nymvpn.BuildConfig
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** Lab-only username/password auth against nym-mock-api. */
object LabAuthClient {
	private const val TAG = "lab-auth"
	private val json = Json { ignoreUnknownKeys = true }

	private val baseUrl: String
		get() = BuildConfig.LAB_AUTH_BASE_URL.trimEnd('/')

	@Serializable
	private data class CredRequest(
		val username: String,
		val password: String,
	)

	@Serializable
	private data class LoginResponse(
		val username: String,
		val mnemonic: String,
	)

	@Serializable
	private data class RegisterResponse(
		val username: String,
		val message: String? = null,
	)

	@Serializable
	private data class ErrorResponse(
		val error: String? = null,
	)

	sealed class LabAuthException(message: String) : IOException(message) {
		class BadRequest(msg: String) : LabAuthException(msg)
		class Conflict(msg: String) : LabAuthException(msg)
		class Unauthorized(msg: String) : LabAuthException(msg)
		class Server(msg: String) : LabAuthException(msg)
	}

	suspend fun register(username: String, password: String) {
		post("register", CredRequest(username, password), RegisterResponse.serializer(), 201)
	}

	suspend fun login(username: String, password: String): String {
		val resp = post("login", CredRequest(username, password), LoginResponse.serializer(), 200)
		return resp.mnemonic
	}

	private suspend fun <T> post(path: String, body: CredRequest, deserializer: kotlinx.serialization.KSerializer<T>, okCode: Int): T {
		return kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
			val url = URL("$baseUrl/$path")
			val conn = (url.openConnection() as HttpURLConnection).apply {
				requestMethod = "POST"
				connectTimeout = 15_000
				readTimeout = 15_000
				doOutput = true
				setRequestProperty("Content-Type", "application/json; charset=utf-8")
			}
			try {
				conn.outputStream.bufferedWriter().use { it.write(json.encodeToString(CredRequest.serializer(), body)) }
				val code = conn.responseCode
				val stream = if (code in 200..299) conn.inputStream else conn.errorStream
				val text = stream?.bufferedReader()?.readText().orEmpty()
				Log.d(TAG, "POST $path -> $code")
				if (code == okCode) {
					return@withContext json.decodeFromString(deserializer, text)
				}
				val err = runCatching { json.decodeFromString(ErrorResponse.serializer(), text).error }.getOrNull()
				val msg = err ?: "HTTP $code"
				throw when (code) {
					400 -> LabAuthException.BadRequest(msg)
					401, 403 -> LabAuthException.Unauthorized(msg)
					409 -> LabAuthException.Conflict(msg)
					else -> LabAuthException.Server(msg)
				}
			} finally {
				conn.disconnect()
			}
		}
	}
}
