import sqlite3
import random
from datetime import datetime, timedelta
from faker import Faker
import math

# -----------------------------
# Config (Optimised for 20K Orders)
# -----------------------------
SEED = 42
random.seed(SEED)
fake = Faker("en_GB")
Faker.seed(SEED)

DB_PATH = "wedeliver.db"
SCHEMA_PATH = "schema.sql"

# -----------------------------
# Record Targets (Balanced & Realistic)
# -----------------------------
N_STORES = 500              # Meets 500+ requirement
N_CUSTOMERS = 5000          # Realistic customer base
N_CATEGORIES = 40           # Supporting table
N_PRODUCTS = 8000           # ~16 per store average
N_PROMOS = 1200             # Multiple promos per store
N_ORDERS = 20000            # Reduced for performance
AVG_ITEMS_PER_ORDER = 3     # ~60,000 OrderItems expected

PROMO_USAGE_RATE = 0.60     # 60% of orders use promotions
RETURN_RATE = 0.10          # ~10% of delivered orders produce returns

# -----------------------------
# Time Range (24 Months)
# -----------------------------
START_DATE = datetime.now() - timedelta(days=730)  # 24 months
END_DATE = datetime.now()

# -----------------------------
# Distributions
# -----------------------------
PLAN_TYPES = ["Basic", "Growth", "Pro"]
PLAN_WEIGHTS = [0.50, 0.35, 0.15]

STORE_STATUS = ["active", "suspended", "closed"]
STORE_STATUS_WEIGHTS = [0.85, 0.10, 0.05]

ORDER_STATUSES = ["paid", "shipped", "delivered", "cancelled"]
ORDER_STATUS_WEIGHTS = [0.10, 0.15, 0.70, 0.05]

PAY_METHODS = ["card", "wallet", "bank_transfer"]

PAY_STATUS = ["succeeded", "failed", "refunded", "partial_refund"]
PAY_STATUS_WEIGHTS = [0.95, 0.03, 0.015, 0.005]

PROMO_TYPES = ["percent", "fixed", "free_shipping"]
PROMO_TYPE_WEIGHTS = [0.60, 0.35, 0.05]

RETURN_STATUSES = ["requested", "approved", "received", "refunded"]

RETURN_REASONS = ["damaged", "late", "not_as_described", "changed_mind"]
RETURN_REASON_WEIGHTS = [0.30, 0.20, 0.35, 0.15]

# -----------------------------
# Helpers
# -----------------------------
def iso_date(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d")

def iso_dt(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")

def rand_dt(start: datetime, end: datetime) -> datetime:
    # uniform random datetime
    delta = end - start
    sec = random.randint(0, int(delta.total_seconds()))
    return start + timedelta(seconds=sec)

def weighted_choice(items, weights):
    return random.choices(items, weights=weights, k=1)[0]

def clamp_money(x: float) -> float:
    # round to 2 decimals, avoid -0.00
    return round(max(0.0, x), 2)

# -----------------------------
# DB setup
# -----------------------------
conn = sqlite3.connect(DB_PATH)
conn.execute("PRAGMA foreign_keys = ON;")

with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
    conn.executescript(f.read())

cur = conn.cursor()

# -----------------------------
# 1) Stores
# -----------------------------
stores = []
for _ in range(N_STORES):
    signup = rand_dt(START_DATE, END_DATE)
    stores.append((
        fake.company()[:120],
        weighted_choice(PLAN_TYPES, PLAN_WEIGHTS),
        iso_date(signup),
        fake.city()[:80],
        "United Kingdom",
        weighted_choice(STORE_STATUS, STORE_STATUS_WEIGHTS)
    ))

cur.executemany("""
INSERT INTO Stores(store_name, plan_type, signup_date, store_city, store_country, store_status)
VALUES (?, ?, ?, ?, ?, ?)
""", stores)
conn.commit()

store_ids = [r[0] for r in cur.execute("SELECT store_id FROM Stores").fetchall()]

# -----------------------------
# 2) Customers
# -----------------------------
customers = []
emails = set()
for _ in range(N_CUSTOMERS):
    signup = rand_dt(START_DATE, END_DATE)
    email = fake.email()
    while email in emails:
        email = fake.email()
    emails.add(email)

    customers.append((
        fake.first_name()[:60],
        fake.last_name()[:60],
        email[:120],
        iso_date(signup),
        fake.city()[:80],
        "United Kingdom",
        1 if random.random() < 0.35 else 0
    ))

cur.executemany("""
INSERT INTO Customers(first_name, last_name, email, signup_date, customer_city, customer_country, marketing_opt_in)
VALUES (?, ?, ?, ?, ?, ?, ?)
""", customers)
conn.commit()

customer_ids = [r[0] for r in cur.execute("SELECT customer_id FROM Customers").fetchall()]

# -----------------------------
# 3) Categories
# -----------------------------
# A mix of general e-commerce categories (works for Shopify-like platform)
category_names = [
    "Snacks", "Beverages", "Health & Wellness", "Personal Care", "Home & Kitchen",
    "Electronics", "Accessories", "Fashion", "Sports & Fitness", "Books & Stationery",
    "Baby & Kids", "Pet Supplies", "Beauty", "Gifts", "Eco Products", "Food Staples",
    "Frozen", "Dairy", "Bakery", "Supplements", "Garden", "Travel", "Office", "Gaming",
    "Phones", "Audio", "Cleaning", "Laundry", "Cookware", "Decor", "Lighting", "Tools",
    "Toys", "Jewellery", "Footwear", "Bags", "Outdoor", "Crafts", "Art", "Tea & Coffee"
]
category_names = category_names[:N_CATEGORIES]

cur.executemany("""
INSERT INTO Categories(category_name, category_desc)
VALUES (?, ?)
""", [(c, f"{c} products") for c in category_names])
conn.commit()

category_ids = [r[0] for r in cur.execute("SELECT category_id FROM Categories").fetchall()]

# -----------------------------
# 4) Products
# -----------------------------
products = []
for _ in range(N_PRODUCTS):
    store_id = random.choice(store_ids)
    category_id = random.choice(category_ids)
    created = rand_dt(START_DATE, END_DATE)

    # price distribution: many low-mid, few high
    base_price = random.choice([
        random.uniform(5, 30),
        random.uniform(30, 80),
        random.uniform(80, 300)
    ])
    unit_price = clamp_money(base_price)

    # cost as 40-70% of price for realistic gross margin
    unit_cost = clamp_money(unit_price * random.uniform(0.40, 0.70))

    products.append((
        store_id,
        category_id,
        fake.catch_phrase()[:140],
        unit_price,
        unit_cost,
        1 if random.random() < 0.90 else 0,
        iso_date(created)
    ))

cur.executemany("""
INSERT INTO Products(store_id, category_id, product_name, unit_price, unit_cost, is_active, created_date)
VALUES (?, ?, ?, ?, ?, ?, ?)
""", products)
conn.commit()

product_rows = cur.execute("SELECT product_id, store_id, unit_price, unit_cost FROM Products WHERE is_active=1").fetchall()

# group products by store for realistic ordering (customers buy from one store per order)
products_by_store = {}
for pid, sid, price, cost in product_rows:
    products_by_store.setdefault(sid, []).append((pid, float(price), float(cost)))

# -----------------------------
# 5) Promotions
# -----------------------------
promos = []
promo_codes = set()

for _ in range(N_PROMOS):
    store_id = random.choice(store_ids)
    ptype = weighted_choice(PROMO_TYPES, PROMO_TYPE_WEIGHTS)

    if ptype == "percent":
        pvalue = random.choice([5, 10, 15, 20, 25])
    elif ptype == "fixed":
        pvalue = random.choice([2, 5, 8, 10, 15])
    else:
        pvalue = 0

    min_spend = random.choice([0, 10, 20, 30, 50])

    start = rand_dt(START_DATE, END_DATE - timedelta(days=30))
    end = start + timedelta(days=random.choice([14, 30, 60, 90]))
    if end > END_DATE:
        end = END_DATE

    code = fake.bothify(text="WD?????##").upper()
    while code in promo_codes:
        code = fake.bothify(text="WD?????##").upper()
    promo_codes.add(code)

    status = "active" if end > datetime.now() else "expired"

    promos.append((
        store_id, code, ptype, float(pvalue), float(min_spend),
        iso_date(start), iso_date(end), status
    ))

cur.executemany("""
INSERT INTO Promotions(store_id, promo_code, promo_type, promo_value, min_spend, start_date, end_date, promo_status)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
""", promos)
conn.commit()

promo_rows = cur.execute("""
SELECT promo_id, store_id, promo_type, promo_value, min_spend, start_date, end_date
FROM Promotions
""").fetchall()

promos_by_store = {}
for row in promo_rows:
    promo_id, sid, ptype, pval, min_sp, sd, ed = row
    promos_by_store.setdefault(sid, []).append({
        "promo_id": promo_id,
        "type": ptype,
        "value": float(pval),
        "min_spend": float(min_sp),
        "start": datetime.strptime(sd, "%Y-%m-%d"),
        "end": datetime.strptime(ed, "%Y-%m-%d")
    })

# -----------------------------
# 6) Orders + 7) OrderItems + 8) Payments + 9) OrderPromotions
# -----------------------------
orders_to_insert = []
orderitems_to_insert = []
payments_to_insert = []
orderpromos_to_insert = []

# Create a heavy-user distribution by pre-weighting customers
# 20% loyal, 50% occasional, 30% one-time
loyal_customers = set(random.sample(customer_ids, int(0.20 * len(customer_ids))))
occasional_customers = set(random.sample([c for c in customer_ids if c not in loyal_customers], int(0.50 * len(customer_ids))))
# rest are one-time by default

def choose_customer():
    r = random.random()
    if r < 0.20:
        return random.choice(list(loyal_customers))
    elif r < 0.70:
        return random.choice(list(occasional_customers))
    return random.choice(customer_ids)

def choose_store():
    # skew store popularity: 10% stores get 40% orders
    top_stores = store_ids[:max(1, int(0.10 * len(store_ids)))]
    if random.random() < 0.40:
        return random.choice(top_stores)
    return random.choice(store_ids)

def compute_tax(subtotal):
    return clamp_money(subtotal * random.uniform(0.05, 0.20))

def compute_shipping():
    # free shipping sometimes
    return clamp_money(0 if random.random() < 0.15 else random.uniform(1.0, 5.0))

order_id_counter = 0  # will map once inserted
order_records = []

for i in range(N_ORDERS):
    cust_id = choose_customer()
    store_id = choose_store()

    # ensure store has products
    if store_id not in products_by_store or len(products_by_store[store_id]) < 5:
        store_id = random.choice([sid for sid in products_by_store.keys()])

    order_dt = rand_dt(START_DATE, END_DATE)
    status = weighted_choice(ORDER_STATUSES, ORDER_STATUS_WEIGHTS)

    # pick number of items: around AVG_ITEMS_PER_ORDER
    n_items = max(1, int(random.gauss(AVG_ITEMS_PER_ORDER, 1)))
    store_products = products_by_store[store_id]

    # choose distinct products often
    chosen = random.sample(store_products, k=min(n_items, len(store_products)))

    subtotal = 0.0
    line_items = []
    for (pid, price, cost) in chosen:
        qty = random.randint(1, 4)
        unit_price_at_purchase = float(price) * random.uniform(0.95, 1.05)  # small variation
        unit_price_at_purchase = clamp_money(unit_price_at_purchase)
        line_subtotal = clamp_money(qty * unit_price_at_purchase)

        line_items.append({
            "product_id": pid,
            "quantity": qty,
            "unit_price_at_purchase": unit_price_at_purchase,
            "line_subtotal": line_subtotal,
            "line_discount": 0.0,  # filled later if we choose line-level allocation
            "line_total": line_subtotal
        })
        subtotal += line_subtotal

    subtotal = clamp_money(subtotal)
    shipping_fee = compute_shipping()
    tax_amount = compute_tax(subtotal)

    # Determine promotions (60% of orders)
    discount_total = 0.0
    applied_promos = []

    if random.random() < PROMO_USAGE_RATE and store_id in promos_by_store:
        # candidate promos valid by date & min spend
        candidates = []
        for p in promos_by_store[store_id]:
            if p["start"] <= order_dt <= p["end"] and subtotal >= p["min_spend"]:
                candidates.append(p)

        if candidates:
            # apply 1 promo usually, 2 sometimes, 3 rarely
            k = 1
            u = random.random()
            if u < 0.15:
                k = 2
            if u < 0.03:
                k = 3
            k = min(k, len(candidates))
            selected = random.sample(candidates, k=k)

            for p in selected:
                if p["type"] == "percent":
                    d = subtotal * (p["value"] / 100.0)
                elif p["type"] == "fixed":
                    d = p["value"]
                else:  # free_shipping
                    d = shipping_fee

                d = clamp_money(d)
                applied_promos.append((p["promo_id"], d))

            # cap total discount to subtotal + shipping_fee (so order total doesn't go negative)
            discount_total = clamp_money(sum(d for _, d in applied_promos))
            max_disc = clamp_money(subtotal + shipping_fee)
            if discount_total > max_disc:
                # scale down proportionally
                scale = max_disc / discount_total if discount_total > 0 else 0
                applied_promos = [(pid, clamp_money(d * scale)) for pid, d in applied_promos]
                discount_total = clamp_money(sum(d for _, d in applied_promos))

    order_total = clamp_money(subtotal + shipping_fee + tax_amount - discount_total)

    # Payment logic
    payment_dt = order_dt + timedelta(minutes=random.randint(1, 120))
    pmethod = random.choice(PAY_METHODS)
    pstatus = weighted_choice(PAY_STATUS, PAY_STATUS_WEIGHTS)

    # If cancelled, likely failed or succeeded? We'll make cancelled often failed.
    if status == "cancelled" and random.random() < 0.70:
        pstatus = "failed"

    if pstatus == "failed":
        amount_paid = 0.0
    else:
        amount_paid = order_total

    # Collect order record (insert later)
    order_records.append((
        store_id, cust_id, iso_dt(order_dt), status,
        shipping_fee, tax_amount, subtotal, discount_total, order_total,
        iso_dt(payment_dt), pmethod, pstatus, amount_paid,
        applied_promos,
        line_items
    ))

# Insert orders first
cur.executemany("""
INSERT INTO Orders(store_id, customer_id, order_datetime, order_status, shipping_fee, tax_amount, order_subtotal, discount_total, order_total)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
""", [r[:9] for r in order_records])
conn.commit()

# Fetch order ids back in insertion order (SQLite rowid pattern)
order_ids = [r[0] for r in cur.execute("SELECT order_id FROM Orders ORDER BY order_id").fetchall()]

# Now insert dependent tables
for idx, order_id in enumerate(order_ids):
    _, _, order_dt, status, _, _, _, _, order_total, pay_dt, pmethod, pstatus, amount_paid, applied_promos, line_items = order_records[idx]

    # OrderItems
    for li in line_items:
        orderitems_to_insert.append((
            order_id,
            li["product_id"],
            li["quantity"],
            li["unit_price_at_purchase"],
            li["line_subtotal"],
            li["line_discount"],
            li["line_total"]
        ))

    # Payments (1 per order)
    payments_to_insert.append((
        order_id,
        pay_dt,
        pmethod,
        pstatus,
        amount_paid,
        "GBP"
    ))

    # OrderPromotions
    for promo_id, disc in applied_promos:
        orderpromos_to_insert.append((
            order_id,
            promo_id,
            disc,
            order_dt  # applied at order time
        ))

# Bulk inserts
cur.executemany("""
INSERT INTO OrderItems(order_id, product_id, quantity, unit_price_at_purchase, line_subtotal, line_discount, line_total)
VALUES (?, ?, ?, ?, ?, ?, ?)
""", orderitems_to_insert)

cur.executemany("""
INSERT INTO Payments(order_id, payment_datetime, payment_method, payment_status, amount_paid, currency)
VALUES (?, ?, ?, ?, ?, ?)
""", payments_to_insert)

cur.executemany("""
INSERT INTO OrderPromotions(order_id, promo_id, discount_amount_applied, applied_datetime)
VALUES (?, ?, ?, ?)
""", orderpromos_to_insert)

conn.commit()

# -----------------------------
# 10) Returns + 11) ReturnItems (partial)
# -----------------------------
# Choose delivered orders that succeeded payment
delivered_orders = cur.execute("""
SELECT o.order_id, o.customer_id, o.order_datetime, p.amount_paid
FROM Orders o
JOIN Payments p ON p.order_id = o.order_id
WHERE o.order_status = 'delivered' AND p.payment_status IN ('succeeded','partial_refund','refunded')
""").fetchall()

n_returns = min(int(len(delivered_orders) * RETURN_RATE), 8000)  # cap safety
returned_orders_sample = random.sample(delivered_orders, k=n_returns)

returns_to_insert = []
returnitems_to_insert = []

# Insert Returns first, then ReturnItems
for (order_id, cust_id, order_dt_str, amount_paid) in returned_orders_sample:
    order_dt = datetime.strptime(order_dt_str, "%Y-%m-%d %H:%M:%S")
    return_dt = order_dt + timedelta(days=random.randint(2, 45))

    rstatus = random.choice(RETURN_STATUSES)
    reason = weighted_choice(RETURN_REASONS, RETURN_REASON_WEIGHTS)

    returns_to_insert.append((
        order_id,
        cust_id,
        iso_dt(return_dt),
        rstatus,
        reason,
        0.0  # refund_total computed after items
    ))

cur.executemany("""
INSERT INTO Returns(order_id, customer_id, return_request_date, return_status, return_reason_group, refund_total)
VALUES (?, ?, ?, ?, ?, ?)
""", returns_to_insert)
conn.commit()

# Map order_id -> return_id (assumes 1 return event per selected order for simplicity)
return_rows = cur.execute("""
SELECT return_id, order_id, return_request_date
FROM Returns
ORDER BY return_id
""").fetchall()

order_to_return = {order_id: (return_id, return_request_date) for (return_id, order_id, return_request_date) in return_rows}

# Create partial return items: return 1-2 order items per return
for (order_id, cust_id, order_dt_str, amount_paid) in returned_orders_sample:
    if order_id not in order_to_return:
        continue
    return_id, return_request_date = order_to_return[order_id]

    items = cur.execute("""
    SELECT order_item_id, quantity, unit_price_at_purchase
    FROM OrderItems
    WHERE order_id = ?
    """, (order_id,)).fetchall()

    if not items:
        continue

    k = 1 if random.random() < 0.75 else 2
    chosen_items = random.sample(items, k=min(k, len(items)))

    refund_total = 0.0
    for (order_item_id, qty, unit_price_at_purchase) in chosen_items:
        qty = int(qty)
        ret_qty = random.randint(1, qty)  # partial
        refund_amt = clamp_money(ret_qty * float(unit_price_at_purchase))
        refund_total += refund_amt

        returnitems_to_insert.append((
            return_id,
            order_item_id,
            ret_qty,
            refund_amt,
            fake.sentence(nb_words=6)[:255] if random.random() < 0.30 else None
        ))

    # cap refund_total to amount_paid
    refund_total = clamp_money(min(refund_total, float(amount_paid)))

    # update Returns.refund_total
    cur.execute("UPDATE Returns SET refund_total = ? WHERE return_id = ?", (refund_total, return_id))

cur.executemany("""
INSERT INTO ReturnItems(return_id, order_item_id, return_quantity, refund_amount, item_reason_detail)
VALUES (?, ?, ?, ?, ?)
""", returnitems_to_insert)

conn.commit()

print("Done. Database generated:", DB_PATH)
print("Row counts:")
for table in ["Stores","Customers","Categories","Products","Orders","OrderItems","Payments",
              "Promotions","OrderPromotions","Returns","ReturnItems"]:
    c = cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    print(f"  {table}: {c}")

conn.close()
