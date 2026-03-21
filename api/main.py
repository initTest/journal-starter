from dotenv import load_dotenv
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from api.repositories.postgres_repository import PostgresDB
from api.routers.journal_router import router as journal_router

load_dotenv()

# TODO: Setup basic console logging
# Hint: Use logging.basicConfig() with level=logging.INFO
# Steps:
# 1. Configure logging with basicConfig()
# 2. Set level to logging.INFO
# 3. Add console handler
# 4. Test by adding a log message when the app starts

app = FastAPI(title="Journal API", description="A simple journal API for tracking daily work, struggles, and intentions")
app.include_router(journal_router)

# Expose Prometheus metrics at /metrics
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.on_event("startup")
async def startup_event():
    # 🔗 Hook into your existing DB logic
    async with PostgresDB() as db:
        print("📁 Auto-checking database schema...")
        
        # Open your already-existing SQL file
        with open("database_setup.sql", "r") as f:
            setup_sql = f.read()
        
        # This will ONLY create the table if it's missing!
        async with db.pool.acquire() as conn:
            await conn.execute(setup_sql)
            print("✅ Database synchronization complete!")

