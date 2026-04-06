from pathlib import Path
import time

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# ===== 1. MySQL connection =====
username = "root"
password = "20060807"
host = "127.0.0.1"
port = 3306
database = "olist_db"

# ===== 2. Paths and chunk sizes =====
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "Kaggle_statistcs"
READ_CHUNK_SIZE = 5000
INSERT_CHUNK_SIZE = 1000

CSV_FILES = {
    "olist_customers_dataset": "olist_customers_dataset.csv",
    "olist_geolocation_dataset": "olist_geolocation_dataset.csv",
    "olist_order_items_dataset": "olist_order_items_dataset.csv",
    "olist_order_payments_dataset": "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset": "olist_order_reviews_dataset.csv",
    "olist_orders_dataset": "olist_orders_dataset.csv",
    "olist_products_dataset": "olist_products_dataset.csv",
    "olist_sellers_dataset": "olist_sellers_dataset.csv",
    "product_category_name_translation": "product_category_name_translation.csv",
    "olist_closed_deals_dataset": "olist_closed_deals_dataset.csv",
    "olist_marketing_qualified_leads_dataset": "olist_marketing_qualified_leads_dataset.csv",
}

TABLE_IMPORT_ORDER = [
    "olist_customers_dataset",
    "olist_products_dataset",
    "olist_sellers_dataset",
    "product_category_name_translation",
    "olist_geolocation_dataset",
    "olist_marketing_qualified_leads_dataset",
    "olist_orders_dataset",
    "olist_order_items_dataset",
    "olist_order_payments_dataset",
    "olist_order_reviews_dataset",
    "olist_closed_deals_dataset",
]

DATETIME_COLUMNS = {
    "olist_closed_deals_dataset": ["won_date"],
    "olist_order_items_dataset": ["shipping_limit_date"],
    "olist_order_reviews_dataset": [
        "review_creation_date",
        "review_answer_timestamp",
    ],
    "olist_orders_dataset": [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
}

DATE_COLUMNS = {
    "olist_marketing_qualified_leads_dataset": ["first_contact_date"],
}

INTEGER_COLUMNS = {
    "olist_order_items_dataset": ["order_item_id"],
    "olist_order_payments_dataset": [
        "payment_sequential",
        "payment_installments",
    ],
    "olist_order_reviews_dataset": ["review_score"],
    "olist_products_dataset": [
        "product_name_lenght",
        "product_description_lenght",
        "product_photos_qty",
        "product_weight_g",
        "product_length_cm",
        "product_height_cm",
        "product_width_cm",
    ],
    "olist_closed_deals_dataset": ["declared_product_catalog_size"],
}

DECIMAL_COLUMNS = {
    "olist_geolocation_dataset": ["geolocation_lat", "geolocation_lng"],
    "olist_order_items_dataset": ["price", "freight_value"],
    "olist_order_payments_dataset": ["payment_value"],
    "olist_closed_deals_dataset": ["declared_monthly_revenue"],
}

BOOLEAN_COLUMNS = {
    "olist_closed_deals_dataset": ["has_company", "has_gtin"],
}

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
    print(f"MySQL connection succeeded, database `{database}` is ready.")


def recreate_tables(engine):
    table_names = list(reversed(TABLE_IMPORT_ORDER))
    with engine.begin() as conn:
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
        try:
            for table_name in table_names:
                conn.execute(text(f"DROP TABLE IF EXISTS `{table_name}`"))
        finally:
            conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))

    with engine.begin() as conn:
        # These two source relationships contain orphan values in the CSV files,
        # so they are intentionally not enforced as foreign keys:
        # 1. olist_closed_deals_dataset.seller_id -> olist_sellers_dataset.seller_id
        # 2. olist_products_dataset.product_category_name
        #    -> product_category_name_translation.product_category_name
        conn.execute(
            text(
                """
                CREATE TABLE `olist_customers_dataset` (
                    `customer_id` VARCHAR(32) NOT NULL,
                    `customer_unique_id` VARCHAR(32) NOT NULL,
                    `customer_zip_code_prefix` VARCHAR(5) NOT NULL,
                    `customer_city` VARCHAR(255) NOT NULL,
                    `customer_state` VARCHAR(2) NOT NULL,
                    PRIMARY KEY (`customer_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_products_dataset` (
                    `product_id` VARCHAR(32) NOT NULL,
                    `product_category_name` VARCHAR(255) DEFAULT NULL,
                    `product_name_lenght` INT DEFAULT NULL,
                    `product_description_lenght` INT DEFAULT NULL,
                    `product_photos_qty` INT DEFAULT NULL,
                    `product_weight_g` INT DEFAULT NULL,
                    `product_length_cm` INT DEFAULT NULL,
                    `product_height_cm` INT DEFAULT NULL,
                    `product_width_cm` INT DEFAULT NULL,
                    PRIMARY KEY (`product_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_sellers_dataset` (
                    `seller_id` VARCHAR(32) NOT NULL,
                    `seller_zip_code_prefix` VARCHAR(5) NOT NULL,
                    `seller_city` VARCHAR(255) NOT NULL,
                    `seller_state` VARCHAR(2) NOT NULL,
                    PRIMARY KEY (`seller_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `product_category_name_translation` (
                    `product_category_name` VARCHAR(255) NOT NULL,
                    `product_category_name_english` VARCHAR(255) NOT NULL,
                    PRIMARY KEY (`product_category_name`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_geolocation_dataset` (
                    `geolocation_zip_code_prefix` VARCHAR(5) NOT NULL,
                    `geolocation_lat` DECIMAL(11,8) NOT NULL,
                    `geolocation_lng` DECIMAL(11,8) NOT NULL,
                    `geolocation_city` VARCHAR(255) NOT NULL,
                    `geolocation_state` VARCHAR(2) NOT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_marketing_qualified_leads_dataset` (
                    `mql_id` VARCHAR(32) NOT NULL,
                    `first_contact_date` DATE NOT NULL,
                    `landing_page_id` VARCHAR(32) NOT NULL,
                    `origin` VARCHAR(255) DEFAULT NULL,
                    PRIMARY KEY (`mql_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_orders_dataset` (
                    `order_id` VARCHAR(32) NOT NULL,
                    `customer_id` VARCHAR(32) NOT NULL,
                    `order_status` VARCHAR(32) NOT NULL,
                    `order_purchase_timestamp` DATETIME NOT NULL,
                    `order_approved_at` DATETIME DEFAULT NULL,
                    `order_delivered_carrier_date` DATETIME DEFAULT NULL,
                    `order_delivered_customer_date` DATETIME DEFAULT NULL,
                    `order_estimated_delivery_date` DATETIME NOT NULL,
                    PRIMARY KEY (`order_id`),
                    KEY `idx_orders_customer_id` (`customer_id`),
                    CONSTRAINT `fk_orders_customer_id`
                        FOREIGN KEY (`customer_id`)
                        REFERENCES `olist_customers_dataset` (`customer_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_order_items_dataset` (
                    `order_id` VARCHAR(32) NOT NULL,
                    `order_item_id` INT NOT NULL,
                    `product_id` VARCHAR(32) NOT NULL,
                    `seller_id` VARCHAR(32) NOT NULL,
                    `shipping_limit_date` DATETIME NOT NULL,
                    `price` DECIMAL(10,2) NOT NULL,
                    `freight_value` DECIMAL(10,2) NOT NULL,
                    PRIMARY KEY (`order_id`, `order_item_id`),
                    KEY `idx_order_items_product_id` (`product_id`),
                    KEY `idx_order_items_seller_id` (`seller_id`),
                    CONSTRAINT `fk_order_items_order_id`
                        FOREIGN KEY (`order_id`)
                        REFERENCES `olist_orders_dataset` (`order_id`),
                    CONSTRAINT `fk_order_items_product_id`
                        FOREIGN KEY (`product_id`)
                        REFERENCES `olist_products_dataset` (`product_id`),
                    CONSTRAINT `fk_order_items_seller_id`
                        FOREIGN KEY (`seller_id`)
                        REFERENCES `olist_sellers_dataset` (`seller_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_order_payments_dataset` (
                    `order_id` VARCHAR(32) NOT NULL,
                    `payment_sequential` SMALLINT NOT NULL,
                    `payment_type` VARCHAR(32) NOT NULL,
                    `payment_installments` SMALLINT NOT NULL,
                    `payment_value` DECIMAL(10,2) NOT NULL,
                    PRIMARY KEY (`order_id`, `payment_sequential`),
                    CONSTRAINT `fk_order_payments_order_id`
                        FOREIGN KEY (`order_id`)
                        REFERENCES `olist_orders_dataset` (`order_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_order_reviews_dataset` (
                    `review_id` VARCHAR(32) NOT NULL,
                    `order_id` VARCHAR(32) NOT NULL,
                    `review_score` SMALLINT NOT NULL,
                    `review_comment_title` VARCHAR(255) DEFAULT NULL,
                    `review_comment_message` TEXT,
                    `review_creation_date` DATETIME NOT NULL,
                    `review_answer_timestamp` DATETIME NOT NULL,
                    PRIMARY KEY (`review_id`, `order_id`),
                    KEY `idx_order_reviews_order_id` (`order_id`),
                    CONSTRAINT `fk_order_reviews_order_id`
                        FOREIGN KEY (`order_id`)
                        REFERENCES `olist_orders_dataset` (`order_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE `olist_closed_deals_dataset` (
                    `mql_id` VARCHAR(32) NOT NULL,
                    `seller_id` VARCHAR(32) NOT NULL,
                    `sdr_id` VARCHAR(32) NOT NULL,
                    `sr_id` VARCHAR(32) NOT NULL,
                    `won_date` DATETIME NOT NULL,
                    `business_segment` VARCHAR(255) DEFAULT NULL,
                    `lead_type` VARCHAR(255) DEFAULT NULL,
                    `lead_behaviour_profile` VARCHAR(64) DEFAULT NULL,
                    `has_company` BOOLEAN DEFAULT NULL,
                    `has_gtin` BOOLEAN DEFAULT NULL,
                    `average_stock` VARCHAR(32) DEFAULT NULL,
                    `business_type` VARCHAR(64) DEFAULT NULL,
                    `declared_product_catalog_size` INT DEFAULT NULL,
                    `declared_monthly_revenue` DECIMAL(14,2) NOT NULL,
                    PRIMARY KEY (`mql_id`),
                    CONSTRAINT `fk_closed_deals_mql_id`
                        FOREIGN KEY (`mql_id`)
                        REFERENCES `olist_marketing_qualified_leads_dataset` (`mql_id`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
                """
            )
        )


def prepare_dataframe(table_name, df):
    df = df.copy()

    for column in DATE_COLUMNS.get(table_name, []):
        df[column] = pd.to_datetime(df[column], errors="coerce").dt.date

    for column in DATETIME_COLUMNS.get(table_name, []):
        df[column] = pd.to_datetime(df[column], errors="coerce")

    for column in INTEGER_COLUMNS.get(table_name, []):
        df[column] = pd.to_numeric(df[column], errors="coerce").astype("Int64")

    for column in DECIMAL_COLUMNS.get(table_name, []):
        df[column] = pd.to_numeric(df[column], errors="coerce")

    for column in BOOLEAN_COLUMNS.get(table_name, []):
        df[column] = df[column].map({"True": True, "False": False})

    return df.astype(object).where(pd.notna(df), None)


def import_one_csv(engine, table_name):
    file_name = CSV_FILES[table_name]
    file_path = DATA_DIR / file_name

    if not file_path.exists():
        print(f"Skip: file does not exist -> {file_path}")
        return

    start_time = time.time()
    total_rows = 0
    print(f"Importing {file_name} -> {table_name}")

    try:
        chunk_iter = pd.read_csv(
            file_path,
            dtype="string",
            chunksize=READ_CHUNK_SIZE,
            low_memory=False,
        )
        for chunk in chunk_iter:
            prepared = prepare_dataframe(table_name, chunk)
            prepared.to_sql(
                name=table_name,
                con=engine,
                if_exists="append",
                index=False,
                chunksize=INSERT_CHUNK_SIZE,
                method="multi",
            )
            total_rows += len(prepared)

        elapsed = time.time() - start_time
        print(
            f"Finished {file_name}: {total_rows} rows inserted in {elapsed:.1f}s"
        )
    except Exception as exc:
        print(f"Import failed: {file_name}")
        print(f"Error: {type(exc).__name__}: {exc}")
        raise


def main():
    engine = None
    try:
        ensure_database_exists()
        engine = build_engine(database)
        test_connection(engine)
        recreate_tables(engine)

        for table_name in TABLE_IMPORT_ORDER:
            import_one_csv(engine, table_name)

        print("All CSV files were imported into MySQL with explicit schema.")
    except SQLAlchemyError as exc:
        print(
            "MySQL operation failed. Check credentials, server status, "
            "permissions, or server-side limits."
        )
        raise exc
    finally:
        if engine is not None:
            engine.dispose()


if __name__ == "__main__":
    main()