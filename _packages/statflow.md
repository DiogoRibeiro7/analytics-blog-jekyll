---
layout: package
title: StatFlow
tagline: A modern statistical analysis toolkit for Python
description: StatFlow provides an intuitive API for statistical modeling, hypothesis testing, and data analysis with seamless integration into the scientific Python ecosystem.
icon: 📊
version: 1.2.3
language: Python
license: MIT
github_url: https://github.com/example/statflow
pypi_url: https://pypi.org/project/statflow/

nav_sections:
  - title: Getting Started
    items:
      - id: installation
        title: Installation
      - id: quick-start
        title: Quick Start
      - id: basic-concepts
        title: Basic Concepts

  - title: API Reference
    items:
      - id: statistical-tests
        title: Statistical Tests
      - id: regression-models
        title: Regression Models
      - id: distributions
        title: Distributions
      - id: utilities
        title: Utilities

  - title: Examples
    items:
      - id: hypothesis-testing
        title: Hypothesis Testing
      - id: regression-analysis
        title: Regression Analysis
      - id: time-series
        title: Time Series Analysis

versions:
  - version: 1.2.3
    url: /packages/statflow/
    status: latest
  - version: 1.1.0
    url: /packages/statflow/v1.1.0/
    status: stable
  - version: 1.0.0
    url: /packages/statflow/v1.0.0/

---

## Installation {#installation}

{% include components/package-install.html
   package_name="statflow"
   language="python" %}

### Requirements

- Python 3.8 or higher
- NumPy >= 1.20.0
- SciPy >= 1.7.0
- Pandas >= 1.3.0

### Optional Dependencies

For advanced visualization features:

```bash
pip install statflow[viz]
```

For GPU acceleration:

```bash
pip install statflow[gpu]
```

## Quick Start {#quick-start}

Here's a simple example to get you started with StatFlow:

```python
import statflow as sf
import numpy as np

# Generate sample data
np.random.seed(42)
x = np.random.normal(100, 15, 1000)
y = np.random.normal(105, 15, 1000)

# Perform t-test
result = sf.ttest(x, y)
print(f"t-statistic: {result.statistic:.4f}")
print(f"p-value: {result.pvalue:.4f}")

# Fit a linear regression
model = sf.LinearRegression()
model.fit(x.reshape(-1, 1), y)
print(f"R-squared: {model.rsquared:.4f}")
```

## Basic Concepts {#basic-concepts}

StatFlow is built around three core concepts:

### 1. Statistical Tests

All statistical tests in StatFlow return a `TestResult` object with standardized attributes:

- `statistic`: The test statistic value
- `pvalue`: The p-value
- `confidence_interval`: Confidence intervals (when applicable)
- `effect_size`: Standardized effect size measures

### 2. Models

Statistical models follow the scikit-learn API pattern:

- `fit(X, y)`: Fit the model to data
- `predict(X)`: Make predictions
- `summary()`: Get detailed model statistics

### 3. Distributions

Work with probability distributions using a consistent interface:

```python
dist = sf.Normal(mu=0, sigma=1)
samples = dist.sample(1000)
pdf_values = dist.pdf(samples)
cdf_values = dist.cdf(samples)
```

## Statistical Tests {#statistical-tests}

StatFlow provides a comprehensive suite of statistical tests for various scenarios.

{% include components/api-function.html
   name="ttest"
   signature="statflow.ttest(x, y=None, paired=False, alternative='two-sided', confidence=0.95)"
   description="Perform a Student's t-test to compare means."
   parameters='[
     {
       "name": "x",
       "type": "array-like",
       "description": "First sample or the sample to test against a population mean.",
       "optional": false
     },
     {
       "name": "y",
       "type": "array-like",
       "description": "Second sample. If None, performs a one-sample t-test.",
       "optional": true,
       "default": "None"
     },
     {
       "name": "paired",
       "type": "bool",
       "description": "If True, performs a paired t-test.",
       "optional": true,
       "default": "False"
     },
     {
       "name": "alternative",
       "type": "str",
       "description": "Defines the alternative hypothesis: **two-sided**, **less**, or **greater**.",
       "optional": true,
       "default": "two-sided"
     },
     {
       "name": "confidence",
       "type": "float",
       "description": "Confidence level for the confidence interval (0-1).",
       "optional": true,
       "default": "0.95"
     }
   ]'
   returns="TestResult"
   return_description="Object containing test statistic, p-value, confidence interval, and effect size (Cohen's d)."
   examples='
import statflow as sf
import numpy as np

# Two-sample t-test
group1 = np.random.normal(100, 15, 50)
group2 = np.random.normal(105, 15, 50)
result = sf.ttest(group1, group2)
print(f"p-value: {result.pvalue:.4f}")

# One-sample t-test
sample = np.random.normal(100, 15, 100)
result = sf.ttest(sample, mu=95)
print(f"95% CI: {result.confidence_interval}")
'
   see_also="[mannwhitneyu](#mannwhitneyu), [anova](#anova)" %}

{% include components/api-function.html
   name="mannwhitneyu"
   signature="statflow.mannwhitneyu(x, y, alternative='two-sided')"
   description="Perform the Mann-Whitney U test for independent samples."
   parameters='[
     {
       "name": "x",
       "type": "array-like",
       "description": "First sample.",
       "optional": false
     },
     {
       "name": "y",
       "type": "array-like",
       "description": "Second sample.",
       "optional": false
     },
     {
       "name": "alternative",
       "type": "str",
       "description": "Defines the alternative hypothesis: **two-sided**, **less**, or **greater**.",
       "optional": true,
       "default": "two-sided"
     }
   ]'
   returns="TestResult"
   return_description="Object containing U statistic, p-value, and rank-biserial correlation effect size."
   examples="
# Non-parametric alternative to t-test
result = sf.mannwhitneyu(group1, group2)
print(f\"U statistic: {result.statistic:.2f}\")
"
   see_also="[ttest](#ttest), [kruskal](#kruskal)" %}

{% include components/api-function.html
   name="anova"
   signature="statflow.anova(*groups, post_hoc=None)"
   description="Perform one-way analysis of variance (ANOVA)."
   parameters='[
     {
       "name": "*groups",
       "type": "array-like",
       "description": "Two or more sample groups to compare.",
       "optional": false
     },
     {
       "name": "post_hoc",
       "type": "str",
       "description": "Post-hoc test to perform: **tukey**, **bonferroni**, or None.",
       "optional": true,
       "default": "None"
     }
   ]'
   returns="ANOVAResult"
   return_description="Object containing F-statistic, p-value, eta-squared effect size, and post-hoc results if requested."
   examples="
# Compare multiple groups
group1 = np.random.normal(100, 15, 30)
group2 = np.random.normal(105, 15, 30)
group3 = np.random.normal(110, 15, 30)

result = sf.anova(group1, group2, group3, post_hoc='tukey')
print(result.summary())
"
   see_also="[kruskal](#kruskal), [ttest](#ttest)" %}

## Regression Models {#regression-models}

Build and evaluate regression models with ease.

{% include components/api-function.html
   name="LinearRegression"
   signature="statflow.LinearRegression(fit_intercept=True, normalize=False)"
   description="Ordinary least squares linear regression."
   parameters='[
     {
       "name": "fit_intercept",
       "type": "bool",
       "description": "Whether to calculate the intercept for this model.",
       "optional": true,
       "default": "True"
     },
     {
       "name": "normalize",
       "type": "bool",
       "description": "If True, the regressors X will be normalized before regression.",
       "optional": true,
       "default": "False"
     }
   ]'
   returns="LinearRegression"
   return_description="Fitted linear regression model with methods for prediction and diagnostics."
   examples='
# Fit linear regression
X = np.random.randn(100, 3)
y = 2*X[:, 0] + 3*X[:, 1] - X[:, 2] + np.random.randn(100)*0.5

model = sf.LinearRegression()
model.fit(X, y)

print(f"Coefficients: {model.coef_}")
print(f"R-squared: {model.rsquared:.4f}")
print(f"Adjusted R-squared: {model.rsquared_adj:.4f}")

# Get detailed summary
print(model.summary())

# Make predictions
predictions = model.predict(X)
'
   see_also="[RidgeRegression](#ridgeregression), [LogisticRegression](#logisticregression)" %}

## Distributions {#distributions}

Work with probability distributions using a unified interface.

{% include components/api-function.html
   name="Normal"
   signature="statflow.Normal(mu=0, sigma=1)"
   description="Normal (Gaussian) distribution."
   parameters='[
     {
       "name": "mu",
       "type": "float",
       "description": "Mean of the distribution.",
       "optional": true,
       "default": "0"
     },
     {
       "name": "sigma",
       "type": "float",
       "description": "Standard deviation of the distribution (must be positive).",
       "optional": true,
       "default": "1"
     }
   ]'
   returns="Normal"
   return_description="Normal distribution object with methods for sampling, pdf, cdf, and quantiles."
   examples='
# Create a normal distribution
dist = sf.Normal(mu=100, sigma=15)

# Sample from the distribution
samples = dist.sample(1000)

# Compute probability density
x = np.linspace(50, 150, 100)
pdf_values = dist.pdf(x)

# Compute cumulative distribution
cdf_values = dist.cdf(x)

# Get quantiles
median = dist.quantile(0.5)
q95 = dist.quantile(0.95)
'
   see_also="[StudentT](#studentt), [Exponential](#exponential)" %}

## Utilities {#utilities}

Helper functions for data analysis and statistics.

{% include components/api-function.html
   name="bootstrap"
   signature="statflow.bootstrap(data, statistic, n_resamples=10000, confidence=0.95, random_state=None)"
   description="Compute bootstrap confidence intervals for a statistic."
   parameters='[
     {
       "name": "data",
       "type": "array-like",
       "description": "Input data to bootstrap.",
       "optional": false
     },
     {
       "name": "statistic",
       "type": "callable",
       "description": "Function that computes the statistic of interest. Should accept an array and return a scalar.",
       "optional": false
     },
     {
       "name": "n_resamples",
       "type": "int",
       "description": "Number of bootstrap resamples to generate.",
       "optional": true,
       "default": "10000"
     },
     {
       "name": "confidence",
       "type": "float",
       "description": "Confidence level for the interval (0-1).",
       "optional": true,
       "default": "0.95"
     },
     {
       "name": "random_state",
       "type": "int",
       "description": "Seed for random number generator for reproducibility.",
       "optional": true,
       "default": "None"
     }
   ]'
   returns="BootstrapResult"
   return_description="Object containing bootstrap distribution, confidence interval, and standard error."
   examples='
# Estimate confidence interval for median
data = np.random.exponential(scale=2, size=100)
result = sf.bootstrap(data, np.median, random_state=42)

print(f"Median: {np.median(data):.4f}")
print(f"95% CI: {result.confidence_interval}")
print(f"Bootstrap SE: {result.standard_error:.4f}")
'
   see_also="[permutation_test](#permutation_test)" %}

## Hypothesis Testing {#hypothesis-testing}

### Example: A/B Testing

Compare conversion rates between two groups:

```python
import statflow as sf
import numpy as np

# Simulate A/B test data
np.random.seed(42)
group_a_conversions = np.random.binomial(1, 0.10, 1000)  # 10% conversion
group_b_conversions = np.random.binomial(1, 0.12, 1000)  # 12% conversion

# Perform proportion test
result = sf.proportions_test(
    [group_a_conversions.sum(), group_b_conversions.sum()],
    [len(group_a_conversions), len(group_b_conversions)]
)

print(f"Group A conversion: {group_a_conversions.mean():.2%}")
print(f"Group B conversion: {group_b_conversions.mean():.2%}")
print(f"p-value: {result.pvalue:.4f}")

if result.pvalue < 0.05:
    print("Significant difference detected!")
else:
    print("No significant difference.")
```

### Example: Multiple Comparisons

When testing multiple hypotheses, control for false discovery rate:

```python
# Simulate 20 hypothesis tests
p_values = [sf.ttest(
    np.random.normal(0, 1, 100),
    np.random.normal(0.2 if i < 5 else 0, 1, 100)
).pvalue for i in range(20)]

# Apply Benjamini-Hochberg correction
adjusted = sf.multipletests(p_values, method='fdr_bh', alpha=0.05)

print(f"Significant tests (uncorrected): {sum(p < 0.05 for p in p_values)}")
print(f"Significant tests (FDR corrected): {sum(adjusted.reject)}")
```

## Regression Analysis {#regression-analysis}

### Example: Multiple Linear Regression

```python
import statflow as sf
import pandas as pd
import numpy as np

# Generate synthetic data
np.random.seed(42)
n = 200

data = pd.DataFrame({
    'hours_studied': np.random.uniform(0, 10, n),
    'sleep_hours': np.random.uniform(4, 10, n),
    'previous_score': np.random.uniform(50, 100, n)
})

# Generate exam scores with some noise
data['exam_score'] = (
    3.5 * data['hours_studied'] +
    2.0 * data['sleep_hours'] +
    0.5 * data['previous_score'] +
    np.random.normal(0, 5, n)
)

# Fit model
X = data[['hours_studied', 'sleep_hours', 'previous_score']]
y = data['exam_score']

model = sf.LinearRegression()
model.fit(X, y)

# Print summary
print(model.summary())

# Check assumptions
diagnostics = model.diagnostics()
print(f"Durbin-Watson: {diagnostics.durbin_watson:.2f}")
print(f"Condition Number: {diagnostics.condition_number:.2f}")

# Visualize residuals
model.plot_residuals()
```

### Example: Logistic Regression

```python
# Binary classification
X = np.random.randn(500, 5)
z = 1.5*X[:, 0] - 0.8*X[:, 1] + np.random.randn(500)*0.5
y = (z > 0).astype(int)

model = sf.LogisticRegression()
model.fit(X, y)

# Predictions
probabilities = model.predict_proba(X)
predictions = model.predict(X)

# Evaluate
print(f"Accuracy: {(predictions == y).mean():.2%}")
print(f"AUC-ROC: {model.roc_auc_score(X, y):.4f}")

# Confusion matrix
print(model.confusion_matrix(y, predictions))
```

## Time Series Analysis {#time-series}

### Example: Autocorrelation Analysis

```python
import statflow as sf
import numpy as np

# Generate AR(1) process
np.random.seed(42)
n = 500
rho = 0.7
y = np.zeros(n)
y[0] = np.random.randn()

for t in range(1, n):
    y[t] = rho * y[t-1] + np.random.randn()

# Compute autocorrelation
acf_values = sf.acf(y, nlags=20)
pacf_values = sf.pacf(y, nlags=20)

# Plot ACF/PACF
sf.plot_acf(y, lags=20)
sf.plot_pacf(y, lags=20)

# Test for stationarity
adf_result = sf.adfuller(y)
print(f"ADF Statistic: {adf_result.statistic:.4f}")
print(f"p-value: {adf_result.pvalue:.4f}")
```

### Example: Moving Average Smoothing

```python
# Noisy time series
t = np.linspace(0, 10, 200)
signal = np.sin(t) + 0.3 * np.random.randn(200)

# Apply moving average
smoothed = sf.moving_average(signal, window=10)

# Exponential smoothing
ema = sf.exponential_smoothing(signal, alpha=0.3)
```

<div class="admonition note">
  <p class="admonition-title">Note</p>
  <p>For more advanced time series modeling including ARIMA, SARIMA, and state space models, see a dedicated time series package.</p>
</div>

## Changelog

### Version 1.2.3 (2025-01-15)

**Added:**
- New `bootstrap()` function with percentile and BCa methods
- Support for weighted statistics in most functions
- GPU acceleration for large-scale computations (requires `statflow[gpu]`)

**Fixed:**
- Improved numerical stability in `LinearRegression` for ill-conditioned matrices
- Fixed edge case in `mannwhitneyu()` with ties
- Corrected confidence interval calculation in paired t-tests

**Changed:**
- Updated minimum NumPy version to 1.20.0 for better type hints
- Improved performance of `anova()` by 40% through vectorization

### Version 1.1.0 (2024-11-20)

**Added:**
- Multiple comparison corrections (`multipletests()`)
- Proportion tests (`proportions_test()`)
- Effect size calculations for all major tests

**Fixed:**
- Memory leak in bootstrap resampling
- Incorrect degrees of freedom in ANOVA with unequal sample sizes

### Version 1.0.0 (2024-09-01)

Initial release with core functionality:
- Basic statistical tests (t-test, Mann-Whitney U, ANOVA, etc.)
- Linear and logistic regression
- Common probability distributions
- Time series utilities

## Contributing

We welcome contributions! Please see our [Contributing Guide](https://github.com/example/statflow/blob/main/CONTRIBUTING.md) for details.

## License

StatFlow is released under the MIT License. See [LICENSE](https://github.com/example/statflow/blob/main/LICENSE) for details.

## Citation

If you use StatFlow in your research, please cite:

```bibtex
@software{statflow2024,
  title = {StatFlow: A Modern Statistical Analysis Toolkit},
  author = {StatFlow Contributors},
  year = {2024},
  url = {https://github.com/example/statflow},
  version = {1.2.3}
}
```
