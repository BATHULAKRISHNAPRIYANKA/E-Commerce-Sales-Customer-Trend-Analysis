"""
E-Commerce 100K - Python & Statistical Analysis
Run: python python_analysis.py
Reads the cleaned CSVs and produces:
  - console summary stats
  - hypothesis tests (ANOVA, chi-square, correlation)
  - RFM customer segmentation
  - charts saved to ./charts/
"""
import pandas as pd
import numpy as np
from scipy import stats
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

plt.rcParams['figure.figsize'] = (9,5)
plt.rcParams['axes.spines.top'] = False
plt.rcParams['axes.spines.right'] = False

cust = pd.read_csv('../Customers_cleaned.csv')
prod = pd.read_csv('../Products_cleaned.csv')
ordr = pd.read_csv('../Orders_cleaned.csv', parse_dates=['OrderDate'])
df = ordr.merge(cust, on='CustomerID').merge(prod, on='ProductID')

print("="*70)
print("1. DESCRIPTIVE STATISTICS")
print("="*70)
print(df[['OrderValue','Quantity','UnitPrice','Rating']].describe().round(2))

# ---------------------------------------------------------------
# CHART 1: Monthly revenue trend
# ---------------------------------------------------------------
m = df[df['IsPartialPeriod']=='N'].groupby('OrderYearMonth').agg(
    orders=('OrderID','count'), revenue=('OrderValue','sum')).reset_index()
fig, ax = plt.subplots()
ax.plot(m['OrderYearMonth'], m['revenue']/1e6, marker='o', linewidth=1.8, color='#2E5077')
ax.set_title('Monthly Revenue Trend (Jan 2024 - Jun 2026)')
ax.set_ylabel('Revenue (Rs. Millions)')
ax.set_xticks(range(0,len(m),3))
ax.set_xticklabels(m['OrderYearMonth'][::3], rotation=45, ha='right')
ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('%.0f'))
plt.tight_layout()
plt.savefig('charts/01_monthly_revenue_trend.png', dpi=130)
plt.close()

# ---------------------------------------------------------------
# CHART 2: Revenue by category
# ---------------------------------------------------------------
cat = df.groupby('Category')['OrderValue'].sum().sort_values(ascending=True)/1e6
fig, ax = plt.subplots()
ax.barh(cat.index, cat.values, color='#2E5077')
ax.set_title('Revenue by Category')
ax.set_xlabel('Revenue (Rs. Millions)')
plt.tight_layout()
plt.savefig('charts/02_revenue_by_category.png', dpi=130)
plt.close()

# ---------------------------------------------------------------
# CHART 3: Order status distribution
# ---------------------------------------------------------------
status = df['OrderStatus'].value_counts()
fig, ax = plt.subplots()
colors = ['#2E5077','#5B8DBE','#E8A33D','#C0504D']
ax.pie(status.values, labels=status.index, autopct='%1.1f%%', colors=colors, startangle=90)
ax.set_title('Order Status Distribution')
plt.tight_layout()
plt.savefig('charts/03_order_status_distribution.png', dpi=130)
plt.close()

# ---------------------------------------------------------------
# CHART 4: Orders-per-customer distribution
# ---------------------------------------------------------------
opc = df.groupby('CustomerID')['OrderID'].count()
fig, ax = plt.subplots()
ax.hist(opc, bins=range(1,17), color='#2E5077', edgecolor='white', align='left')
ax.set_title('Orders per Customer - Distribution')
ax.set_xlabel('Number of orders placed')
ax.set_ylabel('Number of customers')
plt.tight_layout()
plt.savefig('charts/04_orders_per_customer.png', dpi=130)
plt.close()

# ---------------------------------------------------------------
# CHART 5: RFM segment revenue contribution
# ---------------------------------------------------------------
snapshot = df['OrderDate'].max() + pd.Timedelta(days=1)
rfm = df.groupby('CustomerID').agg(
    Recency=('OrderDate', lambda x: (snapshot - x.max()).days),
    Frequency=('OrderID','count'),
    Monetary=('OrderValue','sum')
).reset_index()
rfm['R_score'] = pd.qcut(rfm['Recency'], 4, labels=[4,3,2,1]).astype(int)
rfm['F_score'] = pd.qcut(rfm['Frequency'].rank(method='first'), 4, labels=[1,2,3,4]).astype(int)
rfm['M_score'] = pd.qcut(rfm['Monetary'], 4, labels=[1,2,3,4]).astype(int)
rfm['RFM_Score'] = rfm['R_score']+rfm['F_score']+rfm['M_score']

def segment(row):
    if row['RFM_Score']>=10: return 'Champions'
    elif row['RFM_Score']>=8: return 'Loyal'
    elif row['RFM_Score']>=6: return 'Potential'
    elif row['RFM_Score']>=4: return 'At Risk'
    else: return 'Lost'
rfm['Segment'] = rfm.apply(segment, axis=1)
rfm.to_csv('../rfm_analysis.csv', index=False)

seg_rev = rfm.groupby('Segment')['Monetary'].sum().sort_values(ascending=False)
fig, ax = plt.subplots()
ax.bar(seg_rev.index, seg_rev.values/1e6, color=['#2E5077','#5B8DBE','#8FB4DB','#E8A33D','#C0504D'])
ax.set_title('Revenue Contribution by RFM Segment')
ax.set_ylabel('Revenue (Rs. Millions)')
plt.tight_layout()
plt.savefig('charts/05_rfm_segment_revenue.png', dpi=130)
plt.close()

print("\nRFM segment sizes:")
print(rfm['Segment'].value_counts())
print("\nRFM segment revenue:")
print(seg_rev)

# ---------------------------------------------------------------
# CHART 6: Return/Cancellation rate by category
# ---------------------------------------------------------------
tab = pd.crosstab(df['Category'], df['OrderStatus'], normalize='index')*100
fig, ax = plt.subplots()
tab[['Returned','Cancelled']].plot(kind='bar', ax=ax, color=['#E8A33D','#C0504D'])
ax.set_title('Return & Cancellation Rate by Category')
ax.set_ylabel('% of orders')
ax.legend(title='')
plt.xticks(rotation=30, ha='right')
plt.tight_layout()
plt.savefig('charts/06_return_cancel_by_category.png', dpi=130)
plt.close()

print("\n" + "="*70)
print("2. HYPOTHESIS TESTS")
print("="*70)

groups = [g['OrderValue'].values for _,g in df.groupby('CustomerSegment')]
f,p = stats.f_oneway(*groups)
print(f"\nH1: Does average order value differ by customer segment? (One-way ANOVA)")
print(f"    F={f:.3f}, p={p:.4f}  -> {'Reject H0: significant difference' if p<0.05 else 'Fail to reject H0: no significant difference'}")

groups2 = [g['OrderValue'].values for _,g in df.groupby('Category')]
f2,p2 = stats.f_oneway(*groups2)
print(f"\nH2: Does average order value differ by product category? (One-way ANOVA)")
print(f"    F={f2:.3f}, p={p2:.4f}  -> {'Reject H0: significant difference' if p2<0.05 else 'Fail to reject H0: no significant difference'}")

ct = pd.crosstab(df['Category'], df['OrderStatus'])
chi2,p3,dof,exp = stats.chi2_contingency(ct)
print(f"\nH3: Is order outcome (delivered/returned/cancelled/shipped) associated with category? (Chi-square)")
print(f"    chi2={chi2:.3f}, p={p3:.4f}, dof={dof}  -> {'Associated' if p3<0.05 else 'Independent - no association'}")

ct2 = pd.crosstab(df['PaymentMethod'], df['OrderStatus'])
chi2b,p4,dofb,expb = stats.chi2_contingency(ct2)
print(f"\nH4: Is order outcome associated with payment method? (Chi-square)")
print(f"    chi2={chi2b:.3f}, p={p4:.4f}, dof={dofb}  -> {'Associated' if p4<0.05 else 'Independent - no association'}")

deliv = df[df['OrderStatus']=='Delivered']
r,pr = stats.pearsonr(deliv['UnitPrice'], deliv['Rating'])
print(f"\nH5: Does price correlate with customer rating? (Pearson, delivered orders)")
print(f"    r={r:.4f}, p={pr:.4f}  -> {'Correlated' if pr<0.05 else 'No significant correlation'}")

mean = df['OrderValue'].mean()
sem = stats.sem(df['OrderValue'])
ci = stats.t.interval(0.95, len(df)-1, loc=mean, scale=sem)
print(f"\n95% Confidence Interval for mean Order Value: Rs.{ci[0]:.2f} - Rs.{ci[1]:.2f} (point estimate Rs.{mean:.2f})")

print("\n" + "="*70)
print("3. KEY BUSINESS METRICS")
print("="*70)
one_time = (rfm['Frequency']==1).sum()
print(f"One-time buyers: {one_time} ({one_time/len(rfm)*100:.1f}%)")
print(f"Repeat buyers: {len(rfm)-one_time} ({(len(rfm)-one_time)/len(rfm)*100:.1f}%)")
never_ordered = 25000 - df['CustomerID'].nunique()
print(f"Registered customers who never ordered: {never_ordered} ({never_ordered/25000*100:.1f}%)")

print("\nDone. Charts saved to ./charts/")
