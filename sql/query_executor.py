import sqlite3
from pathlib import Path

# ============================================================
# Locate files relative to this Python script
# ============================================================

sql_folder = Path(__file__).resolve().parent

investigation_file = sql_folder / "01_investigation.sql"
final_file = sql_folder / "final_reconciliation.sql"
database_file = sql_folder / "comm_log.db"

# ============================================================
# Read investigation SQL queries
# ============================================================

query_list = investigation_file.read_text(encoding="utf-8").split(";")[:-1]

# ============================================================
# Connect to SQLite database
# ============================================================

conn = sqlite3.connect(database_file)
cursor = conn.cursor()

# ============================================================
# Execute investigation queries
# ============================================================

action_list = []
column_width = 21

for i, query in enumerate(query_list, start=1):

    query = query.strip()

    if not query:
        continue

    try:
        cursor.execute(query)

        columns = (
            [description[0] for description in cursor.description]
            if cursor.description
            else []
        )

        results = cursor.fetchall()

        action_list.append({
            "query_number": i,
            "query": query,
            "columns": columns,
            "results": results
        })

    except Exception as e:

        action_list.append({
            "query_number": i,
            "query": query,
            "error": str(e)
        })

# ============================================================
# Display investigation results
# ============================================================

for action in action_list:

    print("\n" + "=" * 69)
    print(f"============================== Query {action['query_number']} ==============================")
    print("=" * 69)

    print(action["query"])

    if "error" in action:
        print("\nERROR:")
        print(action["error"])
        continue

    horizontal_border = "+"
    lc_exist, lc_index = "name" in action["columns"], None

    if lc_exist:
        lc_index = action["columns"].index("name")

    for index, value in enumerate(action["columns"]):
        if not lc_exist or lc_index != index:
            horizontal_border += "-" * column_width
        else:
            horizontal_border += "-" * 46
        horizontal_border += "+"

    print(horizontal_border)

    for index, value in enumerate(action["columns"]):
        cw = column_width
        if index == lc_index:
            cw = 46
        if index == 0:
            print(f'|{str(value).center(cw, " ")}|', end="")
        else:
            print(f'{str(value).center(cw, " ")}|', end="")
    print()
    print(horizontal_border)

    for row in action["results"]:
        for index, value in enumerate(row):
            cw = column_width
            if index == lc_index:
                cw = 46
            if index == 0:
                print(f'|{str(value).center(cw, " ")}|', end="")
            else:
                print(f'{str(value).center(cw, " ")}|', end="")
        print()
        print(horizontal_border)

# ============================================================
# Final Reconciliation Result
# ============================================================

print("\n" + "=" * 73)
print("====================== Final Reconciliation Result ======================")
print("=" * 73)

final_query = final_file.read_text(encoding="utf-8")

try:

    cursor.execute(final_query)
    final_result = cursor.fetchall()

    print("\nFinal Result:")

    for row in final_result:
        print(row)

    if final_result:
        print("\nTarget Base:", final_result[0][0])

except Exception as e:

    print("\nFinal reconciliation error:")
    print(e)

# ============================================================
# Close database connection
# ============================================================

conn.close()
