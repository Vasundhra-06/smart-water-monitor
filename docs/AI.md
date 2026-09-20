# AI Trend Analysis Engine — Smart Water Monitor

## 🧠 5-Layer Hybrid Analysis Architecture

The Smart Water Monitor system does NOT rely on simple fixed threshold checks alone. It implements a 5-layer analysis engine:

1. **Layer 1: Parameter Bounds Validation**: Ensures readings fall within physical limits (pH 0-14, TDS >= 0, Turbidity >= 0).
2. **Layer 2: Rolling Baseline & Exponential Moving Average**: Computes tank-specific baseline parameters over a rolling 14-day stability window.
3. **Layer 3: Derivative Peak & Rate-of-Change Detection**: Calculates $\frac{d(\text{Turbidity})}{dt}$ to detect rapid particulate accumulation.
4. **Layer 4: Multi-Parameter Correlation Matrix**: Correlates pH shift, TDS elevation, and Turbidity spikes to rule out single-sensor noise glitches.
5. **Layer 5: Anomaly Severity & Cleaning Recommendation**: Classifies event as `EXCELLENT`, `GOOD`, `ATTENTION`, `POOR`, or `CRITICAL` and triggers cleaning alerts.
