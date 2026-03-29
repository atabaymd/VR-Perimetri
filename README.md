# VR-Perimetri

**Smartphone-based VR visual field testing using iPhone + Google Cardboard**

VR-Perimetri is an iOS application that performs automated visual field (perimetry) testing using a standard iPhone placed inside a Google Cardboard VR headset. It implements Humphrey-style 24-2 grid testing with SITA (Swedish Interactive Thresholding Algorithm) Bayesian threshold estimation.

> **Disclaimer:** This is an academic research prototype. It is not approved as a medical device and must not be used for clinical diagnosis.

---

## Features

- **SITA-Standard & SITA-Fast protocols** — Full Bayesian posterior estimation with bimodal prior (normal + defect components), frequency-of-seeing curve, and growth-pattern stimulus selection
- **Humphrey 24-2 grid** — 54 test locations matching the standard HFA layout
- **Pediatric mode** — Gamified interface with star rewards, age-adaptive grids (toddler 3-5y / child 6-9y / adolescent 10-15y), and simplified instructions
- **Catch trials** — Scheduled false-positive, false-negative, and Heijl-Krakau fixation loss monitoring
- **Real-time SITA growth pattern** — 4 seed points with neighbour propagation, random selection from unlocked pool, inhibition-of-return
- **HFA-style PDF reports** — Single Field Analysis layout with sensitivity map, grayscale, total deviation, pattern deviation, probability maps, global indices (MD, PSD, VFI), and reliability metrics
- **In-app test history** — All results saved locally, browsable history panel with per-test PDF export
- **Patient records** — Name, gender, and age registration per test
- **Stereoscopic VR rendering** — Side-by-side display with per-eye stimulus presentation, monocular and binocular modes
- **Gamepad support** — MFi / Xbox / PS5 controller button input via GCController framework
- **JSON export** — Full test data export for research analysis

## Technical Details

| Component | Detail |
|---|---|
| Platform | iOS 16.0+ (iPhone) |
| VR Headset | Google Cardboard (or compatible) |
| Display | Optimized for iPhone OLED (tested on iPhone 16e, 800 nits, 2532x1170, 457 ppi) |
| Architecture | WKWebView (HTML/CSS/JS) + Swift native bridge |
| Threshold Algorithm | SITA Bayesian with bimodal prior, FOS slope 1.0, posterior SD convergence |
| Stimulus | Goldmann Size III equivalent, white-on-black, 200ms duration |
| PDF Generation | jsPDF (bundled inline, no network dependency) |
| Test Duration | ~2-4 min (SITA-Fast) / ~4-7 min (SITA-Standard) per eye |

## Project Structure

```
VRPerimetri/
├── VRPerimetri.xcodeproj/
├── VRPerimetri/
│   ├── VRPerimetriApp.swift          # App entry point
│   ├── AppDelegate.swift             # UIKit lifecycle
│   ├── PerimetryWebView.swift        # WKWebView + JS-Swift bridge
│   ├── vr-perimetri.html             # Main app (HTML/CSS/JS, ~75K lines app code)
│   ├── jspdf.umd.min.js             # PDF library (bundled)
│   ├── VRPerimetri-Bridging-Header.h
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset/
│       └── AccentColor.colorset/
├── .gitignore
└── README.md
```

## Building

1. Open `VRPerimetri.xcodeproj` in Xcode 15+
2. Select your development team under Signing & Capabilities
3. Connect an iPhone or select a simulator
4. Build and run (Cmd+R)

**Note:** The app requires no external dependencies or package managers. jsPDF is bundled inline within the HTML file to avoid WKWebView network restrictions.

## Algorithm Overview

The SITA implementation follows the real HFA growth-pattern approach:

1. **Initialization** — 4 seed points (one per quadrant) start with age-corrected normal threshold priors
2. **Bayesian estimation** — Each stimulus response updates a posterior PDF via likelihood (logistic FOS, slope=1.0)
3. **Convergence** — A point converges when posterior SD < 1.5 dB (Standard) or < 2.0 dB (Fast), with minimum presentation counts
4. **Neighbour propagation** — When a seed converges, adjacent points are unlocked with blended priors (50% normal + 50% measured neighbour)
5. **Stimulus selection** — Random pick from all unlocked, incomplete points (with inhibition-of-return)
6. **Catch trials** — Scheduled at intervals: fixation loss every ~15 trials, false-positive every ~12, false-negative every ~18

## References

- Bengtsson E, Olsson J, Heijl A, Rootzen H. A new generation of algorithms for computerized threshold perimetry, SITA. *Acta Ophthalmol Scand*. 1997;75(4):368-375.
- Heijl A, Lindgren G, Olsson J. The effect of perimetric experience in normal subjects. *Arch Ophthalmol*. 1989;107(1):81-86.
- Turpin A, McKendrick AM, Johnson CA, Vingrys AJ. Properties of perimetric threshold estimates from full threshold, ZEST, and SITA-like strategies, as determined by computer simulation. *Invest Ophthalmol Vis Sci*. 2003;44(11):4787-4795.
- Kong YXG, He M, Crowston JG, Vingrys AJ. A comparison of perimetric results from a tablet perimeter and Humphrey Field Analyzer in glaucoma patients. *Transl Vis Sci Technol*. 2016;5(6):2.

## License

This project is intended for academic research purposes only.

## Author

Ata Baytaroglu, MD — Ophthalmologist & Research Scientist
