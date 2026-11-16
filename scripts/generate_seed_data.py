"""Generate synthetic seed data for the fuel pricing dbt project.

All names, accounts, and prices are fictional. The structure mirrors a typical
fuel distributor ERP: customer accounts spread across several operating
companies, daily terminal rack prices, customer price agreements, and invoice
lines. A few realistic data-quality issues are planted on purpose (messy account
names, duplicate re-extracted invoice lines, no rack prices on weekends) so the
staging and intermediate models have something real to clean up.

Run from the project root:  python scripts/generate_seed_data.py
"""

import csv
import random
from datetime import date, timedelta
from pathlib import Path

random.seed(1707)
SEEDS = Path(__file__).resolve().parent.parent / "seeds"
START, END = date(2026, 1, 1), date(2026, 6, 30)

COMPANIES = ["NOC", "WIC", "EFC", "SRC"]  # four fictional operating companies

TERMINALS = [
    ("HON", "Honolulu Harbor Terminal", "Oahu"),
    ("KAH", "Kahului Terminal", "Maui"),
    ("HIL", "Hilo Terminal", "Hawaii"),
    ("KAW", "Kawaihae Terminal", "Hawaii"),
    ("NAW", "Nawiliwili Terminal", "Kauai"),
]
# island freight/storage premium added to the base rack price
ISLAND_PREMIUM = {"Oahu": 0.00, "Maui": 0.18, "Hawaii": 0.22, "Kauai": 0.25}

PRODUCTS = [
    ("RUL", "Regular Unleaded 87", "Gasoline", 2.85),
    ("PUL", "Premium Unleaded 91", "Gasoline", 3.20),
    ("ULSD", "Ultra Low Sulfur Diesel", "Diesel", 3.05),
    ("B20", "Biodiesel Blend B20", "Diesel", 3.15),
    ("JETA", "Jet A", "Jet Fuel", 2.95),
    ("MGO", "Marine Gas Oil", "Marine", 3.10),
]

SEGMENTS = ["Retail Station", "Commercial Fleet", "Marine", "Aviation", "Construction"]
NAME_ROOTS = [
    "Aloha Fleet Services", "Pacific Paving", "Island Air Charters", "Kona Marine Supply",
    "Haleakala Tours", "Garden Isle Builders", "Makai Trucking", "Mauka Farms",
    "Lahaina Water Taxi", "Windward Waste Haulers", "Hilo Bay Ferries", "Upcountry Landscaping",
    "North Shore Rentals", "Kauai Coffee Roasters", "Ewa Logistics", "Kihei Fuel Stop",
    "Volcano Excavation", "Leeward Concrete", "Hanalei Charters", "Diamond Head Delivery",
    "Honokaa Ranch", "Kapalua Shuttle", "Pearl City Movers", "Waimea Aviation",
]
SUFFIXES = ["LLC", "Inc", "INC.", "Co.", "llc", "Ltd"]


def messy(name: str) -> str:
    """Make an ERP-style messy account name."""
    variant = random.choice([name.upper(), name, name.lower().title(), f"  {name} "])
    if random.random() < 0.6:
        variant = f"{variant} {random.choice(SUFFIXES)}"
    if random.random() < 0.2:
        variant = variant.replace(" ", "  ", 1)
    return variant


def write(name, header, rows):
    with open(SEEDS / f"{name}.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows)} rows")


# --- terminals & products -------------------------------------------------
write("raw_terminals", ["terminal_code", "terminal_name", "island"], TERMINALS)
write(
    "raw_products",
    ["product_code", "product_name", "product_family", "unit_of_measure"],
    [(c, n, fam, "GAL") for c, n, fam, _ in PRODUCTS],
)

# --- customers: one shared customer_id, one account per company it buys from
customers, accounts = [], []
for i, root in enumerate(NAME_ROOTS, start=1):
    cid = f"C{i:04d}"
    tier = random.choices(["A", "B", "C"], weights=[2, 5, 3])[0]
    customers.append((cid, tier, random.choice(SEGMENTS)))
    for comp in random.sample(COMPANIES, k=random.choice([1, 1, 2, 3])):
        accounts.append((comp, f"{comp}-{random.randint(10000, 99999)}", messy(root), cid, tier,
                         customers[-1][2], (START - timedelta(days=random.randint(30, 900))).isoformat()))
write(
    "raw_customer_accounts",
    ["company_code", "account_number", "account_name", "customer_id", "price_tier", "segment", "created_at"],
    accounts,
)

# --- rack prices: published weekdays only ---------------------------------
rack_rows, rack_lookup = [], {}
drift = {p[0]: 0.0 for p in PRODUCTS}
d = START
while d <= END:
    for code in drift:
        drift[code] += random.gauss(0, 0.02)
    if d.weekday() < 5:
        for tcode, _, island in TERMINALS:
            for pcode, _, _, base in PRODUCTS:
                price = round(base + drift[pcode] + ISLAND_PREMIUM[island] + random.uniform(-0.01, 0.01), 4)
                rack_rows.append((d.isoformat(), tcode, pcode, price))
                rack_lookup[(d, tcode, pcode)] = price
    d += timedelta(days=1)
write("raw_rack_prices", ["price_date", "terminal_code", "product_code", "rack_price"], rack_rows)


def rack_asof(day, tcode, pcode):
    while (day, tcode, pcode) not in rack_lookup:
        day -= timedelta(days=1)
    return rack_lookup[(day, tcode, pcode)]


# --- tier default differentials (cents over rack) --------------------------
tier_rows = []
for tier, base in [("A", 0.08), ("B", 0.14), ("C", 0.21)]:
    for fam in sorted({p[2] for p in PRODUCTS}):
        tier_rows.append((tier, fam, round(base + random.uniform(-0.02, 0.03), 4)))
write("raw_tier_differentials", ["price_tier", "product_family", "rack_differential"], tier_rows)
tier_diff = {(t, f): v for t, f, v in tier_rows}

# --- price agreements: three specificity levels ---------------------------
agreements, agr_id = [], 1
for cid, tier, _ in customers:
    r = random.random()
    if r < 0.35:  # customer-wide rack-plus deal
        agreements.append((f"AGR{agr_id:05d}", cid, "", "", "rack_plus", round(random.uniform(0.04, 0.12), 4),
                           START.isoformat(), ""))
        agr_id += 1
    if r > 0.25:  # product-specific deal
        pcode = random.choice(PRODUCTS)[0]
        agreements.append((f"AGR{agr_id:05d}", cid, pcode, "", "rack_plus", round(random.uniform(0.02, 0.09), 4),
                           START.isoformat(), ""))
        agr_id += 1
    if r > 0.8:  # product + terminal fixed-price contract for part of the period
        pcode = random.choice(PRODUCTS)[0]
        tcode = random.choice(TERMINALS)[0]
        agreements.append((f"AGR{agr_id:05d}", cid, pcode, tcode, "fixed", round(random.uniform(3.1, 3.6), 4),
                           date(2026, 3, 1).isoformat(), date(2026, 5, 31).isoformat()))
        agr_id += 1
write(
    "raw_price_agreements",
    ["agreement_id", "customer_id", "product_code", "terminal_code", "price_type", "price_value",
     "effective_from", "effective_to"],
    agreements,
)


# --- price tier changes (slowly changing attribute) -------------------------
# About a third of customers are re-tiered once during the period after a volume
# review. A separate RNG keeps every other generated row identical.
tier_rng = random.Random(42)
tier_changes = []
for cid, tier, _ in customers:
    if tier_rng.random() < 0.35:
        new_tier = tier_rng.choice([t for t in ("A", "B", "C") if t != tier])
        changed = START + timedelta(days=tier_rng.randint(31, 150))
        tier_changes.append((f"TC{len(tier_changes) + 1:04d}", cid, new_tier, changed.isoformat(),
                             "volume review"))
write("raw_customer_tier_changes",
      ["change_id", "customer_id", "new_price_tier", "changed_at", "change_reason"], tier_changes)
change_by_cust = {c[1]: (c[2], date.fromisoformat(c[3])) for c in tier_changes}


def tier_asof(cid, onboarding_tier, day):
    """Price tier in effect on a given day (onboarding tier until a change takes effect)."""
    if cid in change_by_cust and day >= change_by_cust[cid][1]:
        return change_by_cust[cid][0]
    return onboarding_tier


def expected_price(cid, tier, pcode, fam, tcode, day):
    """Python reference of the waterfall (used only to generate invoice prices)."""
    rack = rack_asof(day, tcode, pcode)
    best = None
    for a in agreements:
        _, acid, ap, at, ptype, val, ef, et = a
        if acid != cid or day < date.fromisoformat(ef) or (et and day > date.fromisoformat(et)):
            continue
        if ap and ap != pcode or at and at != tcode:
            continue
        rank = 1 if (ap and at) else 2 if ap else 3
        if best is None or rank < best[0]:
            best = (rank, ptype, val)
    if best:
        return rack, (best[2] if best[1] == "fixed" else rack + best[2])
    return rack, rack + tier_diff[(tier, fam)]


# --- invoice lines --------------------------------------------------------
lines, inv = [], 100000
acct_by_cust = {}
for a in accounts:
    acct_by_cust.setdefault(a[3], []).append(a)
prod_fam = {p[0]: p[2] for p in PRODUCTS}
d = START
while d <= END:
    for _ in range(random.randint(8, 16)):
        cid, tier, seg = random.choice(customers)
        comp, acct, *_ = random.choice(acct_by_cust[cid])
        pcode = "JETA" if seg == "Aviation" else "MGO" if seg == "Marine" else random.choice(
            ["RUL", "PUL", "ULSD", "B20"])
        tcode = random.choice(TERMINALS)[0]
        rack, exp = expected_price(cid, tier_asof(cid, tier, d), pcode, prod_fam[pcode], tcode, d)
        billed = exp if random.random() > 0.07 else exp + random.choice([-0.05, -0.03, 0.02, 0.04])
        gallons = random.choice([500, 1200, 2500, 4000, 7500, 8000])
        inv += 1
        loaded = f"{d.isoformat()} 23:{random.randint(10, 59)}:00"
        row = (f"INV{inv}", 1, d.isoformat(), comp, acct, pcode, tcode, gallons, round(billed, 4), loaded)
        lines.append(row)
        if random.random() < 0.02:  # duplicate from a re-extract, loaded later
            lines.append(row[:-1] + (f"{(d + timedelta(days=1)).isoformat()} 02:15:00",))
    d += timedelta(days=1)
write(
    "raw_sales_lines",
    ["invoice_id", "line_number", "invoice_date", "company_code", "account_number", "product_code",
     "terminal_code", "gallons", "invoice_unit_price", "loaded_at"],
    lines,
)
