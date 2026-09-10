package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestSelectionScreens(t *testing.T) {
	m := initialModel()
	m.Width = 120
	m.Height = 35

	// Test Section 0: GPU
	v0 := m.renderSelectionScreen()
	if !strings.Contains(v0, "Select Target GPU:") {
		t.Errorf("Section 0 missing GPU header: %s", v0)
	}
	if !strings.Contains(v0, "llama-bench2") {
		t.Errorf("Missing title: %s", v0)
	}

	// Select GPU -> trigger blink
	var cmd tea.Cmd
	var newM tea.Model
	newM, cmd = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = newM.(Model)
	if m.Blink == nil {
		t.Fatal("Expected blink state after selecting GPU")
	}
	if cmd == nil {
		t.Fatal("Expected tick cmd for blink")
	}

	// Step through blink (4 steps at 100ms)
	for i := 0; i < 4; i++ {
		newM, _ = m.Update(BlinkTickMsg{})
		m = newM.(Model)
	}
	if m.Blink != nil {
		t.Errorf("Blink should have completed")
	}
	if m.CurrentSection != 1 {
		t.Errorf("Expected transition to Section 1 (Model), got %d", m.CurrentSection)
	}

	// Test Section 1: Model with fuzzy search
	v1 := m.renderSelectionScreen()
	if !strings.Contains(v1, "Select GGUF Model:") {
		t.Errorf("Section 1 missing Model header: %s", v1)
	}
	if !strings.Contains(v1, "Search: ") {
		t.Errorf("Section 1 missing Search prompt: %s", v1)
	}

	// Test typing in fuzzy search
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'g'}})
	m = newM.(Model)
	if m.ModelSearch != "g" {
		t.Errorf("Expected search query 'g', got '%s'", m.ModelSearch)
	}
	// Clear search
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyEsc})
	m = newM.(Model)
	if m.ModelSearch != "" {
		t.Errorf("Expected empty search query after Esc")
	}

	// Select model
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = newM.(Model)
	for i := 0; i < 4; i++ {
		newM, _ = m.Update(BlinkTickMsg{})
		m = newM.(Model)
	}
	if m.CurrentSection != 2 {
		t.Errorf("Expected transition to Section 2 (Tests), got %d", m.CurrentSection)
	}

	// Test Section 2: Tests
	v2 := m.renderSelectionScreen()
	if !strings.Contains(v2, "Select Tests:") {
		t.Errorf("Section 2 missing Tests header: %s", v2)
	}
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeySpace})
	m = newM.(Model)
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = newM.(Model)
	for i := 0; i < 4; i++ {
		newM, _ = m.Update(BlinkTickMsg{})
		m = newM.(Model)
	}
	if m.CurrentSection != 3 {
		t.Errorf("Expected transition to Section 3 (Misc), got %d", m.CurrentSection)
	}

	// Test Section 3: Misc
	v3 := m.renderSelectionScreen()
	if !strings.Contains(v3, "Configure Benchmark Parameters:") {
		t.Errorf("Section 3 missing Misc header: %s", v3)
	}
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyRight})
	m = newM.(Model)
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyLeft})
	m = newM.(Model)
	newM, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = newM.(Model)
	if m.CurrentSection != 4 {
		t.Errorf("Expected transition to Section 4 (Confirm), got %d", m.CurrentSection)
	}

	// Test Section 4: Confirm
	v4 := m.renderSelectionScreen()
	if !strings.Contains(v4, "Review Benchmark Configuration:") {
		t.Errorf("Section 4 missing Confirm header: %s", v4)
	}
}

func TestBenchmarkScreenLinearGraph(t *testing.T) {
	m := initialModel()
	m.Width = 120
	m.Height = 35
	m.InBenchmarkScreen = true

	m.Telemetry = NewTelemetryEngine("0", 0.5)
	for i := 0; i < 20; i++ {
		m.Telemetry.Samples = append(m.Telemetry.Samples, TelemetrySample{
			Timestamp: float64(i) * 0.5,
			Temp:      50.0 + 10.0*float64(i%5),
			Power:     30.0 + 20.0*float64(i%4),
			Util:      50.0 + 30.0*float64(i%6),
			SMClock:   1800,
			MemClock:  6000,
			VRAM:      2048,
			Throttle:  0,
			TestID:    "pp512",
		})
	}

	m.Results = []TestResult{
		{TestName: "pp512", Prompt: 512, Gen: 0, PPS: 14000.0, TokS: 0, JPerTok: 0.0055, WPerTokS: 0.0055, TokPerKWh: 654000000.0, Status: "Done", EndSample: 15},
	}

	vb := m.renderBenchmarkScreen()
	if !strings.Contains(vb, "Graph of Metrics Over Time") {
		t.Errorf("Missing Graph header: %s", vb)
	}
	if !strings.Contains(vb, "Per-Test Performance & Efficiency") {
		t.Errorf("Missing Table header: %s", vb)
	}
	if !strings.Contains(vb, "Scale: ◄ [1x] ►") {
		t.Errorf("Missing slider: %s", vb)
	}

	// Test mouse hover within [4, 4+graphW)
	m.MouseX = 10
	m.MouseY = 8
	vHover := m.renderBenchmarkScreen()
	if !strings.Contains(vHover, "cur:") || !strings.Contains(vHover, "min:") {
		t.Errorf("Expected hover tooltip: %s", vHover)
	}

	// Test Zoom toggle
	newM, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'-'}})
	m = newM.(Model)
	if m.GraphZoom != 2 {
		t.Errorf("Expected zoom 2, got %d", m.GraphZoom)
	}

	// Test Checkbox click on benchmark screen
	// Panel is at: x in [axisStart + graphW + 2, ...], y in [7, 7+len]
	axisStart := 6
	graphW := m.getGraphWidth()
	chkX := axisStart + graphW + 4
	chkY := 7 // first metric: temp
	origTempState := m.MetricActive["temp"]

	newM, _ = m.Update(tea.MouseMsg{
		X:    chkX,
		Y:    chkY,
		Type: tea.MouseLeft,
	})
	m = newM.(Model)
	if m.MetricActive["temp"] == origTempState {
		t.Errorf("Expected temp metric toggle after clicking at (%d, %d)", chkX, chkY)
	}
}
