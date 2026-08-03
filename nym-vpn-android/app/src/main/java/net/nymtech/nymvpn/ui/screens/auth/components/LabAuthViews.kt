package net.nymtech.nymvpn.ui.screens.auth.components

import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import net.nymtech.nymvpn.R
import net.nymtech.nymvpn.ui.common.animations.SpinningIcon
import net.nymtech.nymvpn.ui.common.buttons.MainStyledButton
import net.nymtech.nymvpn.ui.common.textbox.CustomTextField
import net.nymtech.nymvpn.ui.theme.NymVPNTheme
import net.nymtech.nymvpn.ui.theme.Theme
import net.nymtech.nymvpn.util.extensions.scaledHeight

@Composable
fun LabWelcomeView(
	onLoginClick: () -> Unit,
	onRegisterClick: () -> Unit,
	modifier: Modifier = Modifier,
) {
	Column(
		modifier = modifier
			.background(MaterialTheme.colorScheme.surface)
			.fillMaxWidth()
			.padding(horizontal = 18.dp, vertical = 16.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.spacedBy(22.dp),
	) {
		Icon(
			imageVector = ImageVector.vectorResource(R.drawable.app_label),
			contentDescription = stringResource(R.string.app_name),
			tint = MaterialTheme.colorScheme.onPrimaryContainer,
		)
		Text(
			text = stringResource(R.string.lab_auth_welcome_title),
			style = MaterialTheme.typography.headlineSmall,
			color = MaterialTheme.colorScheme.onPrimaryContainer,
		)
		Text(
			text = stringResource(R.string.lab_auth_welcome_description),
			style = MaterialTheme.typography.bodyMedium,
			color = MaterialTheme.colorScheme.onSurface,
			textAlign = TextAlign.Center,
		)
		MainStyledButton(
			onClick = onRegisterClick,
			content = {
				Text(stringResource(R.string.lab_auth_register_button), style = MaterialTheme.typography.titleMedium)
			},
			modifier = Modifier.fillMaxWidth().height(48.dp.scaledHeight()),
			shape = RoundedCornerShape(12.dp),
		)
		MainStyledButton(
			onClick = onLoginClick,
			content = {
				Text(stringResource(R.string.lab_auth_login_button), style = MaterialTheme.typography.titleMedium)
			},
			modifier = Modifier.fillMaxWidth().height(48.dp.scaledHeight()),
			shape = RoundedCornerShape(12.dp),
		)
	}
}

@Composable
fun LabLoginForm(
	username: String,
	password: String,
	loading: Boolean,
	errorMessage: String?,
	onBackClick: () -> Unit,
	onUsernameChange: (String) -> Unit,
	onPasswordChange: (String) -> Unit,
	onSubmit: () -> Unit,
	modifier: Modifier = Modifier,
) {
	LabCredentialForm(
		title = stringResource(R.string.lab_auth_login_title),
		username = username,
		password = password,
		confirmPassword = null,
		loading = loading,
		errorMessage = errorMessage,
		submitLabel = stringResource(R.string.lab_auth_login_button),
		onBackClick = onBackClick,
		onUsernameChange = onUsernameChange,
		onPasswordChange = onPasswordChange,
		onConfirmPasswordChange = {},
		onSubmit = onSubmit,
		modifier = modifier,
	)
}

@Composable
fun LabRegisterForm(
	username: String,
	password: String,
	confirmPassword: String,
	loading: Boolean,
	errorMessage: String?,
	onBackClick: () -> Unit,
	onUsernameChange: (String) -> Unit,
	onPasswordChange: (String) -> Unit,
	onConfirmPasswordChange: (String) -> Unit,
	onSubmit: () -> Unit,
	modifier: Modifier = Modifier,
) {
	LabCredentialForm(
		title = stringResource(R.string.lab_auth_register_title),
		username = username,
		password = password,
		confirmPassword = confirmPassword,
		loading = loading,
		errorMessage = errorMessage,
		submitLabel = stringResource(R.string.lab_auth_register_button),
		onBackClick = onBackClick,
		onUsernameChange = onUsernameChange,
		onPasswordChange = onPasswordChange,
		onConfirmPasswordChange = onConfirmPasswordChange,
		onSubmit = onSubmit,
		modifier = modifier,
	)
}

@Composable
private fun LabCredentialForm(
	title: String,
	username: String,
	password: String,
	confirmPassword: String?,
	loading: Boolean,
	errorMessage: String?,
	submitLabel: String,
	onBackClick: () -> Unit,
	onUsernameChange: (String) -> Unit,
	onPasswordChange: (String) -> Unit,
	onConfirmPasswordChange: (String) -> Unit,
	onSubmit: () -> Unit,
	modifier: Modifier = Modifier,
) {
	val submit = {
		if (!loading && username.isNotBlank() && password.isNotBlank()) onSubmit()
	}

	Column(
		modifier = modifier
			.background(MaterialTheme.colorScheme.surface)
			.fillMaxWidth()
			.padding(horizontal = 18.dp)
			.padding(top = 16.dp, bottom = 41.dp),
		horizontalAlignment = Alignment.CenterHorizontally,
		verticalArrangement = Arrangement.spacedBy(16.dp),
	) {
		Box(modifier = Modifier.fillMaxWidth()) {
			IconButton(onClick = onBackClick, modifier = Modifier.align(Alignment.CenterStart).size(24.dp)) {
				Icon(
					imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
					tint = MaterialTheme.colorScheme.onBackground,
					contentDescription = stringResource(R.string.button_back),
				)
			}
			Icon(
				imageVector = ImageVector.vectorResource(R.drawable.app_label),
				contentDescription = stringResource(R.string.app_name),
				tint = MaterialTheme.colorScheme.onPrimaryContainer,
				modifier = Modifier.align(Alignment.Center),
			)
		}

		Text(title, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)

		CustomTextField(
			label = { Text(stringResource(R.string.lab_auth_username_hint)) },
			placeholder = { Text(stringResource(R.string.lab_auth_username_hint), color = MaterialTheme.colorScheme.outline) },
			value = username,
			onValueChange = onUsernameChange,
			singleLine = true,
			keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Ascii, imeAction = ImeAction.Next),
			modifier = Modifier.fillMaxWidth(),
		)
		CustomTextField(
			label = { Text(stringResource(R.string.lab_auth_password_hint)) },
			placeholder = { Text(stringResource(R.string.lab_auth_password_hint), color = MaterialTheme.colorScheme.outline) },
			value = password,
			onValueChange = onPasswordChange,
			singleLine = true,
			visualTransformation = PasswordVisualTransformation(),
			keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = if (confirmPassword != null) ImeAction.Next else ImeAction.Done),
			keyboardActions = KeyboardActions(onDone = { submit() }),
			modifier = Modifier.fillMaxWidth(),
		)
		if (confirmPassword != null) {
			CustomTextField(
				label = { Text(stringResource(R.string.lab_auth_confirm_password_hint)) },
				placeholder = { Text(stringResource(R.string.lab_auth_confirm_password_hint), color = MaterialTheme.colorScheme.outline) },
				value = confirmPassword,
				onValueChange = onConfirmPasswordChange,
				singleLine = true,
				visualTransformation = PasswordVisualTransformation(),
				keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, imeAction = ImeAction.Done),
				keyboardActions = KeyboardActions(onDone = { submit() }),
				modifier = Modifier.fillMaxWidth(),
			)
		}

		if (!errorMessage.isNullOrBlank()) {
			Text(
				text = errorMessage,
				color = MaterialTheme.colorScheme.error,
				style = MaterialTheme.typography.bodySmall,
				textAlign = TextAlign.Center,
				modifier = Modifier.fillMaxWidth(),
			)
		}

		MainStyledButton(
			onClick = submit,
			enabled = !loading,
			content = {
				if (loading) {
					SpinningIcon(Icons.Outlined.Lock, "")
				} else {
					Text(submitLabel, style = MaterialTheme.typography.titleMedium)
				}
			},
			modifier = Modifier.fillMaxWidth().height(48.dp.scaledHeight()),
			shape = RoundedCornerShape(12.dp),
		)
	}
}

@Preview(uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun PreviewLabWelcome() {
	NymVPNTheme(Theme.DARK_MODE) {
		LabWelcomeView(onLoginClick = {}, onRegisterClick = {})
	}
}
