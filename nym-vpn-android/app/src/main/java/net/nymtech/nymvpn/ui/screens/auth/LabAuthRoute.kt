package net.nymtech.nymvpn.ui.screens.auth

import kotlinx.serialization.Serializable

sealed interface LabAuthRoute {
	@Serializable data object Welcome : LabAuthRoute

	@Serializable data object Login : LabAuthRoute

	@Serializable data object Register : LabAuthRoute
}
