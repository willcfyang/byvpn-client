package net.nymtech.nymvpn.ui.screens.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import net.nymtech.nymvpn.R
import net.nymtech.nymvpn.auth.LabAuthClient
import net.nymtech.nymvpn.data.SettingsRepository
import net.nymtech.nymvpn.manager.backend.BackendManager
import net.nymtech.nymvpn.ui.common.snackbar.SnackbarController
import net.nymtech.nymvpn.util.StringValue
import timber.log.Timber
import javax.inject.Inject

data class LabAuthUiState(
	val username: String = "",
	val password: String = "",
	val confirmPassword: String = "",
	val isLoading: Boolean = false,
	val errorMessage: String? = null,
)

sealed class LabAuthEvent {
	data class LoginSuccess(val showTechnicalOpt: Boolean) : LabAuthEvent()
	data object RegisterSuccess : LabAuthEvent()
}

@HiltViewModel
class LabAuthViewModel @Inject constructor(
	private val backendManager: BackendManager,
	private val settingsRepository: SettingsRepository,
) : ViewModel() {

	companion object {
		private const val TAG = "lab-auth-vm"
		private const val LOGIN_DELAY_MS = 2_000L
	}

	private val _uiState = MutableStateFlow(LabAuthUiState())
	val uiState = _uiState.asStateFlow()

	private val _events = MutableSharedFlow<LabAuthEvent>(extraBufferCapacity = 1)
	val events = _events.asSharedFlow()

	fun onUsernameChange(value: String) {
		_uiState.update { it.copy(username = value, errorMessage = null) }
	}

	fun onPasswordChange(value: String) {
		_uiState.update { it.copy(password = value, errorMessage = null) }
	}

	fun onConfirmPasswordChange(value: String) {
		_uiState.update { it.copy(confirmPassword = value, errorMessage = null) }
	}

	private suspend fun ensureLabConnectReady() {
		settingsRepository.setCredentialMode(false)
	}

	fun onLogin() = viewModelScope.launch {
		val state = _uiState.value
		if (state.isLoading || state.username.isBlank() || state.password.isBlank()) return@launch

		_uiState.update { it.copy(isLoading = true, errorMessage = null) }
		runCatching {
			ensureLabConnectReady()
			val mnemonic = LabAuthClient.login(state.username.trim(), state.password)
			backendManager.storeMnemonic(mnemonic)
			backendManager.refreshAccount()
			delay(LOGIN_DELAY_MS)
			val showTechnical = !settingsRepository.isTechnicalOptScreenCompleted()
			_events.emit(LabAuthEvent.LoginSuccess(showTechnicalOpt = showTechnical))
			_uiState.update { it.copy(isLoading = false) }
		}.onFailure { t ->
			Timber.tag(TAG).w(t, "LabLoginFailed")
			val msg = when (t) {
				is LabAuthClient.LabAuthException.Unauthorized -> "Invalid username or password"
				is LabAuthClient.LabAuthException -> t.message ?: "Login failed"
				else -> "Login failed"
			}
			_uiState.update { it.copy(isLoading = false, errorMessage = msg) }
			SnackbarController.showMessage(StringValue.DynamicString(msg))
		}
	}

	fun onRegister() = viewModelScope.launch {
		val state = _uiState.value
		if (state.isLoading || state.username.isBlank() || state.password.isBlank()) return@launch
		if (state.password.length < 8) {
			_uiState.update { it.copy(errorMessage = "Password must be at least 8 characters") }
			return@launch
		}
		if (state.password != state.confirmPassword) {
			_uiState.update { it.copy(errorMessage = "Passwords do not match") }
			return@launch
		}

		_uiState.update { it.copy(isLoading = true, errorMessage = null) }
		runCatching {
			ensureLabConnectReady()
			LabAuthClient.register(state.username.trim(), state.password)
			_events.emit(LabAuthEvent.RegisterSuccess)
			_uiState.update { it.copy(isLoading = false, password = "", confirmPassword = "") }
			SnackbarController.showMessage(StringValue.StringResource(R.string.lab_auth_register_success))
		}.onFailure { t ->
			Timber.tag(TAG).w(t, "LabRegisterFailed")
			val msg = when {
				t.message?.contains("Cleartext HTTP", ignoreCase = true) == true ->
					"Lab server requires HTTP access (network config error)"
				t is LabAuthClient.LabAuthException.Conflict -> "Username already taken"
				t is LabAuthClient.LabAuthException.BadRequest -> t.message ?: "Invalid registration"
				t is LabAuthClient.LabAuthException -> t.message ?: "Registration failed"
				else -> t.message ?: "Registration failed"
			}
			_uiState.update { it.copy(isLoading = false, errorMessage = msg) }
			SnackbarController.showMessage(StringValue.DynamicString(msg))
		}
	}
}
