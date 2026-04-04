import os
import time

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# ===== 1. MySQL 连接信息 =====
username = "root"
password = "20060807"
host = "127.0.0.1"
port = 3306
database = "olist_db"

# ===== 2. CSV 文件所在目录 =====
data_dir = os.path.dirname(os.path.abspath(__file__))

# ===== 3. 需要导入的文件列表 =====
csv_files = [
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
    "olist_closed_deals_dataset.csv",
    "olist_marketing_qualified_leads_dataset.csv",
]

# 大文件分批写入时，批次太大更容易触发超时或 max_allowed_packet 错误
chunksize = 1000


def build_engine(db_name=None):
    database_part = f"/{db_name}" if db_name else ""
    return create_engine(
        f"mysql+pymysql://{username}:{password}@{host}:{port}{database_part}?charset=utf8mb4",
        pool_pre_ping=True,
        pool_recycle=3600,
        connect_args={"read_timeout": 600, "write_timeout": 600},
    )


def ensure_database_exists():
    server_engine = build_engine()
    try:
        with server_engine.connect() as conn:
            conn.execute(
                text(
                    f"CREATE DATABASE IF NOT EXISTS `{database}` "
                    "DEFAULT CHARACTER SET utf8mb4"
                )
            )
            conn.commit()
    finally:
        server_engine.dispose()


def test_connection(engine):
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    print(f"MySQL 连接成功，数据库 `{database}` 已就绪")


def import_one_csv(engine, file_name):
    file_path = os.path.join(data_dir, file_name)

    if not os.path.exists(file_path):
        print(f"跳过：文件不存在 -> {file_path}")
        return

    table_name = file_name.replace(".csv", "").lower()
    start_time = time.time()
    print(f"正在导入：{file_name}")

    try:
        df = pd.read_csv(file_path, low_memory=False)
        df.to_sql(
            name=table_name,
            con=engine,
            if_exists="replace",
            index=False,
            chunksize=chunksize,
            method="multi",
        )
        elapsed = time.time() - start_time
        print(f"导入完成：{file_name} -> {table_name}，耗时 {elapsed:.1f} 秒")
    except Exception as exc:
        print(f"导入失败：{file_name}")
        print(f"错误信息：{type(exc).__name__}: {exc}")
        raise


def main():
    engine = None
    try:
        ensure_database_exists()
        engine = build_engine(database)
        test_connection(engine)

        for file_name in csv_files:
            import_one_csv(engine, file_name)

        print("全部 CSV 已导入到 MySQL")
    except SQLAlchemyError as exc:
        print("MySQL 操作失败，请检查账号密码、服务状态、数据库权限或服务器参数。")
        raise exc
    finally:
        if engine is not None:
            engine.dispose()


if __name__ == "__main__":
    main()
