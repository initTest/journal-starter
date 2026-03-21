import asyncio
import asyncpg
import json
import os
import sys

# Tell the script where the API folder is
sys.path.append("/app")

from api.config import get_settings

async def run():
    print("🔌 Connecting to the database...")
    settings = get_settings()
    conn = await asyncpg.connect(settings["DATABASE_URL"])
    
    # We look in /tmp/ because that's where we copied it!
    print("📁 Loading /tmp/database_setup.sql...")
    with open("/tmp/database_setup.sql", "r") as f:
        setup_sql = f.read()
    
    print("🚧 Executing migrations...")
    await conn.execute(setup_sql)
    await conn.close()
    print("✅ DATABASE IS READY")

if __name__ == "__main__":
    asyncio.run(run())
