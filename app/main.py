from fastapi import FastAPI
from app.api.v1 import router as v1_router

app = FastAPI(title="Licensing Cloud Challenge", version="1.0.0")

app.include_router(v1_router)

@app.get("/")
def root():
    return {"message": "Licensing Cloud API", "docs": "/docs"}