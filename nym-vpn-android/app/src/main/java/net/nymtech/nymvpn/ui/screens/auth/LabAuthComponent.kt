package net.nymtech.nymvpn.ui.screens.auth

import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import net.nymtech.nymvpn.ui.Route
import net.nymtech.nymvpn.ui.common.navigation.LocalNavController
import net.nymtech.nymvpn.ui.screens.auth.components.LabLoginForm
import net.nymtech.nymvpn.ui.screens.auth.components.LabRegisterForm
import net.nymtech.nymvpn.ui.screens.auth.components.LabWelcomeView

@Composable
fun LabAuthComponent(
	onAuthSuccess: () -> Unit,
	modifier: Modifier = Modifier,
	viewModel: LabAuthViewModel = hiltViewModel(),
) {
	val localNavController = rememberNavController()
	val rootNavController = LocalNavController.current
	val uiState by viewModel.uiState.collectAsStateWithLifecycle()

	LaunchedEffect(Unit) {
		viewModel.events.collect { event ->
			when (event) {
				is LabAuthEvent.LoginSuccess -> {
					onAuthSuccess()
					if (event.showTechnicalOpt) {
						rootNavController.navigate(Route.Technical)
					}
				}
				is LabAuthEvent.RegisterSuccess -> {
					localNavController.navigate(LabAuthRoute.Login) {
						popUpTo(LabAuthRoute.Welcome)
					}
				}
			}
		}
	}

	NavHost(
		navController = localNavController,
		startDestination = LabAuthRoute.Welcome,
		modifier = modifier.fillMaxWidth().wrapContentHeight(),
		enterTransition = { slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Left, tween(300)) },
		exitTransition = { slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Left, tween(300)) },
		popEnterTransition = { slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Right, tween(300)) },
		popExitTransition = { slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.Right, tween(300)) },
	) {
		composable<LabAuthRoute.Welcome> {
			LabWelcomeView(
				onLoginClick = { localNavController.navigate(LabAuthRoute.Login) },
				onRegisterClick = { localNavController.navigate(LabAuthRoute.Register) },
			)
		}
		composable<LabAuthRoute.Login> {
			LabLoginForm(
				username = uiState.username,
				password = uiState.password,
				loading = uiState.isLoading,
				errorMessage = uiState.errorMessage,
				onBackClick = { localNavController.popBackStack() },
				onUsernameChange = viewModel::onUsernameChange,
				onPasswordChange = viewModel::onPasswordChange,
				onSubmit = viewModel::onLogin,
			)
		}
		composable<LabAuthRoute.Register> {
			LabRegisterForm(
				username = uiState.username,
				password = uiState.password,
				confirmPassword = uiState.confirmPassword,
				loading = uiState.isLoading,
				errorMessage = uiState.errorMessage,
				onBackClick = { localNavController.popBackStack() },
				onUsernameChange = viewModel::onUsernameChange,
				onPasswordChange = viewModel::onPasswordChange,
				onConfirmPasswordChange = viewModel::onConfirmPasswordChange,
				onSubmit = viewModel::onRegister,
			)
		}
	}
}
