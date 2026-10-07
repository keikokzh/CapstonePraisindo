package models_test

import (
	"testing"

	"github.com/shopspring/decimal"
)

// TestFinancialCalculations verifies the calculation formulas for TRX-01:
// - Mockup formula: Net = Gross - Fee
// - Data Model v2 formula: Net = Gross - Fee - Stamp Duty
// - Stamp Duty rule (demo assumption): Rp 10.000 if Gross > Rp 10.000.000, else Rp 0
// - Units = Net / NAV
func TestFinancialCalculations(t *testing.T) {
	tests := []struct {
		name          string
		gross         string
		feePct        string
		nav           string
		expectedStamp string
		expectedFee   string
		expectedNet   string
		expectedUnits string
	}{
		{
			name:          "Gross > 10M with 1% fee (Stamp duty applies)",
			gross:         "50000000.00", // Rp 50.000.000
			feePct:        "0.01",        // 1%
			nav:           "1842.5500",   // NAV per unit
			expectedStamp: "10000.00",    // Stamp duty applies
			expectedFee:   "500000.00",   // Fee = 50M * 1% = 500.000
			expectedNet:   "49490000.00", // Net = 50M - 500K - 10K = 49.490.000
			expectedUnits: "26859.5153",  // Units = 49.490.000 / 1842.55 = 26859.5153
		},
		{
			name:          "Gross <= 10M with 0.5% fee (No stamp duty)",
			gross:         "5000000.00", // Rp 5.000.000
			feePct:        "0.005",      // 0.5%
			nav:           "1215.3000",
			expectedStamp: "0.00",
			expectedFee:   "25000.00",   // Fee = 5M * 0.5% = 25.000
			expectedNet:   "4975000.00", // Net = 5M - 25K = 4.975.000
			expectedUnits: "4093.6394",  // Units = 4.975.000 / 1215.30 = 4093.6394
		},
		{
			name:          "Exactly 10M threshold (No stamp duty, must be > 10M)",
			gross:         "10000000.00",
			feePct:        "0.01",
			nav:           "1000.0000",
			expectedStamp: "0.00",
			expectedFee:   "100000.00",
			expectedNet:   "9900000.00",
			expectedUnits: "9900.0000",
		},
	}

	threshold := decimal.NewFromInt(10000000)
	stampDutyRate := decimal.NewFromInt(10000)

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			gross, _ := decimal.NewFromString(tc.gross)
			feePct, _ := decimal.NewFromString(tc.feePct)
			nav, _ := decimal.NewFromString(tc.nav)

			// 1. Fee calculation
			fee := gross.Mul(feePct).Round(2)
			expectedFee, _ := decimal.NewFromString(tc.expectedFee)
			if !fee.Equal(expectedFee) {
				t.Errorf("Fee mismatch: got %s, want %s", fee, expectedFee)
			}

			// 2. Stamp duty rule (demo assumption per data model)
			var stamp decimal.Decimal
			if gross.GreaterThan(threshold) {
				stamp = stampDutyRate
			} else {
				stamp = decimal.Zero
			}
			expectedStamp, _ := decimal.NewFromString(tc.expectedStamp)
			if !stamp.Equal(expectedStamp) {
				t.Errorf("Stamp duty mismatch: got %s, want %s", stamp, expectedStamp)
			}

			// 3. Net amount calculation
			net := gross.Sub(fee).Sub(stamp)
			expectedNet, _ := decimal.NewFromString(tc.expectedNet)
			if !net.Equal(expectedNet) {
				t.Errorf("Net amount mismatch: got %s, want %s", net, expectedNet)
			}

			// 4. Units calculation with 4 decimal places
			units := net.DivRound(nav, 4)
			expectedUnits, _ := decimal.NewFromString(tc.expectedUnits)
			if !units.Equal(expectedUnits) {
				t.Errorf("Units mismatch: got %s, want %s", units, expectedUnits)
			}
		})
	}
}

func TestNoFloatPrecisionLoss(t *testing.T) {
	// Demonstrates why shopspring/decimal is used instead of float64
	// In float64: 0.1 + 0.2 != 0.3
	d1 := decimal.NewFromFloat(0.1)
	d2 := decimal.NewFromFloat(0.2)
	sum := d1.Add(d2)
	expected := decimal.NewFromFloat(0.3)

	if !sum.Equal(expected) {
		t.Errorf("Decimal precision failed: got %s, want %s", sum, expected)
	}
}
