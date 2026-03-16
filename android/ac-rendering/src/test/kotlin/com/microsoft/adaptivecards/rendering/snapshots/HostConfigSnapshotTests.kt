// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

package com.microsoft.adaptivecards.rendering.snapshots

import app.cash.paparazzi.Paparazzi
import com.microsoft.adaptivecards.core.hostconfig.HostConfigParser
import com.microsoft.adaptivecards.core.hostconfig.TeamsHostConfig
import com.microsoft.adaptivecards.rendering.theme.HostConfigProvider
import com.microsoft.adaptivecards.rendering.composables.AdaptiveCardView
import com.microsoft.adaptivecards.rendering.viewmodel.CardViewModel
import org.junit.Assume.assumeNotNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import java.io.File

/**
 * Snapshot tests that render representative cards across multiple HostConfig presets.
 *
 * This validates that the renderer correctly adapts appearance based on
 * the host configuration — spacing, fonts, colors, container styles, etc.
 *
 * Adding a new host config:
 * 1. Add JSON to shared/test-cards/host-configs/<name>.json
 * 2. Add entry to PRESETS list below
 * 3. Record: ./gradlew :ac-rendering:recordPaparazziDebug
 */
@RunWith(Parameterized::class)
class HostConfigSnapshotTests(
    private val cardName: String,
    private val cardRelativePath: String
) {

    companion object {
        /** Representative cards for host config visual comparison */
        private val REPRESENTATIVE_CARDS = listOf(
            "simple-text", "containers", "all-actions", "all-inputs",
            "table", "accordion", "carousel", "compound-buttons",
            "code-block", "rating", "fluent-theming"
        )

        @JvmStatic
        @Parameterized.Parameters(name = "{0}")
        fun cards(): List<Array<String>> {
            return REPRESENTATIVE_CARDS.map { arrayOf(it, "$it.json") }
        }

        private fun findTestCardsDir(): File? {
            val candidates = listOf(
                "../../shared/test-cards",
                "../shared/test-cards",
                "shared/test-cards",
                "../../../shared/test-cards"
            )
            return candidates.map { File(it) }.firstOrNull { it.isDirectory }
        }

        private fun findHostConfigDir(): File? {
            val candidates = listOf(
                "../../shared/test-cards/host-configs",
                "../shared/test-cards/host-configs",
                "shared/test-cards/host-configs",
                "../../../shared/test-cards/host-configs"
            )
            return candidates.map { File(it) }.firstOrNull { it.isDirectory }
        }

        private fun loadHostConfig(name: String): com.microsoft.adaptivecards.core.hostconfig.HostConfig? {
            val dir = findHostConfigDir() ?: return null
            val file = File(dir, "$name.json")
            if (!file.exists()) return null
            return try { HostConfigParser.parse(file.readText()) } catch (_: Exception) { null }
        }
    }

    @get:Rule
    val paparazzi = Paparazzi(maxPercentDifference = 1.0)

    private fun loadCardJson(): String? {
        val dir = findTestCardsDir() ?: return null
        val file = File(dir, cardRelativePath)
        return if (file.exists()) file.readText() else null
    }

    // Default HostConfig
    @Test
    fun snapshot_defaultConfig() {
        val json = loadCardJson()
        assumeNotNull("Card not found: $cardRelativePath", json)
        paparazzi.snapshot(name = "hc_default_$cardName") {
            AdaptiveCardView(cardJson = json!!, viewModel = CardViewModel())
        }
    }

    // Teams Light HostConfig
    @Test
    fun snapshot_teamsLightConfig() {
        val json = loadCardJson()
        assumeNotNull("Card not found: $cardRelativePath", json)
        val hostConfig = loadHostConfig("microsoft-teams-light") ?: TeamsHostConfig.create()
        paparazzi.snapshot(name = "hc_teamsLight_$cardName") {
            HostConfigProvider(hostConfig = hostConfig) {
                AdaptiveCardView(cardJson = json!!, viewModel = CardViewModel())
            }
        }
    }

    // Teams Dark HostConfig
    @Test
    fun snapshot_teamsDarkConfig() {
        val json = loadCardJson()
        assumeNotNull("Card not found: $cardRelativePath", json)
        val hostConfig = loadHostConfig("microsoft-teams-dark") ?: TeamsHostConfig.createDark()
        paparazzi.snapshot(name = "hc_teamsDark_$cardName") {
            HostConfigProvider(hostConfig = hostConfig) {
                AdaptiveCardView(cardJson = json!!, viewModel = CardViewModel())
            }
        }
    }

    // AC Evolution Light HostConfig (Figma redesign)
    @Test
    fun snapshot_evolutionLightConfig() {
        val json = loadCardJson()
        assumeNotNull("Card not found: $cardRelativePath", json)
        val hostConfig = loadHostConfig("ac-evolution-android-light")
        assumeNotNull("AC Evolution light config not found", hostConfig)
        paparazzi.snapshot(name = "hc_evolutionLight_$cardName") {
            HostConfigProvider(hostConfig = hostConfig!!) {
                AdaptiveCardView(cardJson = json!!, viewModel = CardViewModel())
            }
        }
    }

    // AC Evolution Dark HostConfig (Figma redesign)
    @Test
    fun snapshot_evolutionDarkConfig() {
        val json = loadCardJson()
        assumeNotNull("Card not found: $cardRelativePath", json)
        val hostConfig = loadHostConfig("ac-evolution-android-dark")
        assumeNotNull("AC Evolution dark config not found", hostConfig)
        paparazzi.snapshot(name = "hc_evolutionDark_$cardName") {
            HostConfigProvider(hostConfig = hostConfig!!) {
                AdaptiveCardView(cardJson = json!!, viewModel = CardViewModel())
            }
        }
    }
}
