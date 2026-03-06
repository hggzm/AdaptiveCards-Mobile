package com.microsoft.adaptivecards.accessibility

import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.material3.Text
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Tests that input accessibility modifiers correctly announce
 * required state for TalkBack (upstream #205, #274).
 */
@RunWith(RobolectricTestRunner::class)
class InputRequiredSemanticsTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `inputSemantics should include required in description when isRequired is true`() {
        composeTestRule.setContent {
            Text(
                text = "Name *",
                modifier = Modifier.inputSemantics(
                    label = "Name",
                    value = "",
                    isRequired = true
                )
            )
        }

        composeTestRule
            .onNode(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.ContentDescription,
                    listOf("Name (required)")
                )
            )
            .assertExists()
    }

    @Test
    fun `inputSemantics should not include required when isRequired is false`() {
        composeTestRule.setContent {
            Text(
                text = "Name",
                modifier = Modifier.inputSemantics(
                    label = "Name",
                    value = "John",
                    isRequired = false
                )
            )
        }

        composeTestRule
            .onNode(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.ContentDescription,
                    listOf("Name")
                )
            )
            .assertExists()
    }

    @Test
    fun `inputWithErrorSemantics should include required and error`() {
        composeTestRule.setContent {
            Text(
                text = "Email *",
                modifier = Modifier.inputWithErrorSemantics(
                    label = "Email",
                    value = "bad",
                    isRequired = true,
                    error = "Invalid email"
                )
            )
        }

        composeTestRule
            .onNode(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.ContentDescription,
                    listOf("Email, required, current value: bad, Error: Invalid email")
                )
            )
            .assertExists()
    }

    @Test
    fun `inputWithErrorSemantics without error should still show required`() {
        composeTestRule.setContent {
            Text(
                text = "Phone *",
                modifier = Modifier.inputWithErrorSemantics(
                    label = "Phone",
                    value = "",
                    isRequired = true,
                    error = null
                )
            )
        }

        composeTestRule
            .onNode(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.ContentDescription,
                    listOf("Phone, required")
                )
            )
            .assertExists()
    }
}
