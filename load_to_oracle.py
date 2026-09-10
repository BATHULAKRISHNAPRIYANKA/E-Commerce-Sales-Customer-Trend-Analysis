"""
Alternative loader for smaller / dev setups using python-oracledb.
Usage:
    pip install oracledb pandas
    python load_to_oracle.py
Update the connection string below before running.
"""
import oracledb
import pandas as pd

DSN_USER = "ecom_user"
DSN_PASS = "your_password"
DSN_HOST = "localhost:1521/orclpdb"

def load_df(cursor, df, table, cols):
    placeholders = ", ".join([f":{i+1}" for i in range(len(cols))])
    col_list = ", ".join(cols)
    sql = f"INSERT INTO {table} ({col_list}) VALUES ({placeholders})"
    rows = [tuple(r) for r in df[cols].itertuples(index=False, name=None)]
    cursor.executemany(sql, rows, batcherrors=True)
    for error in cursor.getbatcherrors():
        print(f"Row {error.offset} failed: {error.message}")

def main():
    conn = oracledb.connect(user=DSN_USER, password=DSN_PASS, dsn=DSN_HOST)
    cur = conn.cursor()

    cust = pd.read_csv("Customers_cleaned.csv")
    prod = pd.read_csv("Products_cleaned.csv")
    ordr = pd.read_csv("Orders_cleaned.csv")

    load_df(cur, cust, "CUSTOMERS", ["CustomerID","CustomerName","City","CustomerSegment"])
    load_df(cur, prod, "PRODUCTS", ["ProductID","SKU","Category","UnitPrice","Brand"])

    order_cols = ["OrderID","OrderDate","CustomerID","ProductID","Quantity","OrderValue",
                  "OrderStatus","PaymentMethod","Rating","OrderYear","OrderMonth",
                  "OrderYearMonth","ComputedValue","ValueVariance","ValueVariancePct",
                  "IsDeliveredRating","IsOrderValueOutlier","IsPartialPeriod"]
    load_df(cur, ordr, "ORDERS", order_cols)

    conn.commit()
    print("Load complete:", len(cust), "customers,", len(prod), "products,", len(ordr), "orders")
    cur.close()
    conn.close()

if __name__ == "__main__":
    main()
