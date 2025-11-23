from fastapi import APIRouter, Depends, HTTPException, status, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from jose import jwt, JWTError
from datetime import datetime, timedelta
import time
import logging
from app.database import get_db
from app.redis_client import get_redis
from app.models import License, Application
from app.schemas import (
    LicenseCreate, LicenseTokenPayload, AppRegistrationRequest,
    AppRegistrationResponse, JobStartRequest, JobStartResponse
)
from app.database import Base, engine
import os

# Créer les tables au démarrage
Base.metadata.create_all(bind=engine)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1")
security = HTTPBearer()


def get_private_key():
    with open(os.getenv("JWT_PRIVATE_KEY_PATH"), "rb") as f:
        return f.read()

def get_public_key():
    with open(os.getenv("JWT_PUBLIC_KEY_PATH"), "rb") as f:
        return f.read()

ALGORITHM = "RS256"

@router.post("/licenses")
def create_license(license_data: LicenseCreate, db: Session = Depends(get_db)):
    existing = db.query(License).filter(License.tenant_id == license_data.tenant_id).first()
    if existing:
        raise HTTPException(status_code=409, detail="License already exists")
    
    db_license = License(**license_data.model_dump())
    db.add(db_license)
    db.commit()
    db.refresh(db_license)
    
    # Générer un token
    expire = datetime.utcnow() + timedelta(days=30)
    payload = {
        "tenant_id": db_license.tenant_id,
        "max_apps": db_license.max_apps,
        "max_executions_per_24h": db_license.max_executions_per_24h,
        "valid_from": db_license.valid_from,
        "valid_to": db_license.valid_to,
        "status": db_license.status,
        "exp": int(expire.timestamp()),
        "iat": int(datetime.utcnow().timestamp())
    }
    token = jwt.encode(payload, get_private_key(), algorithm=ALGORITHM)
    
    return {"license": db_license, "token": token}

def verify_license_token(token: str) -> LicenseTokenPayload:
    try:
        payload = jwt.decode(token, get_public_key(), algorithms=[ALGORITHM])
        token_data = LicenseTokenPayload(**payload)
        
        
        if token_data.status != "ACTIVE":
            raise HTTPException(status_code=403, detail="License not active")
        
        now = datetime.utcnow()
        if now < token_data.valid_from.replace(tzinfo=None) or now > token_data.valid_to.replace(tzinfo=None):
            raise HTTPException(status_code=403, detail="License expired or not yet valid")
        
        return token_data
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

@router.post("/apps/register", response_model=AppRegistrationResponse)
def register_app(
    app_data: AppRegistrationRequest,
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(get_db)
):
    payload = verify_license_token(credentials.credentials)
    
    
    license_db = db.query(License).filter(License.tenant_id == payload.tenant_id).first()
    if not license_db:
        raise HTTPException(status_code=404, detail="License not found")
    
    count = db.query(Application).filter(Application.license_id == license_db.id).count()
    if count >= payload.max_apps:
        return AppRegistrationResponse(
            success=False,
            message=f"Max apps ({payload.max_apps}) reached",
            app_id=None
        )
    
    
    app = Application(license_id=license_db.id, app_name=app_data.app_name)
    db.add(app)
    db.commit()
    db.refresh(app)
    
    return AppRegistrationResponse(
        success=True,
        message="Application registered",
        app_id=app.id
    )

@router.post("/jobs/start", response_model=JobStartResponse)
async def start_job(
    job_data: JobStartRequest,
    credentials: HTTPAuthorizationCredentials = Security(security),
    db: Session = Depends(get_db)
):
    payload = verify_license_token(credentials.credentials)
    
    # Vérifier que l'app existe
    license_db = db.query(License).filter(License.tenant_id == payload.tenant_id).first()
    app_exists = db.query(Application).filter(
        Application.license_id == license_db.id,
        Application.app_name == job_data.app_name
    ).first()
    if not app_exists:
        raise HTTPException(status_code=400, detail="Application not registered")
    
    # Vérifier quota exécutions (fenêtre glissante 24h)
    redis = await get_redis()
    key = f"executions:{payload.tenant_id}"
    now = time.time()
    window_start = now - 86400  # 24h en secondes
    
    # Script Lua atomique
    lua_script = """
    local key = KEYS[1]
    local max_exec = tonumber(ARGV[1])
    local now = tonumber(ARGV[2])
    local window_start = tonumber(ARGV[3])
    local job_id = ARGV[4]
    
    redis.call('ZREMRANGEBYSCORE', key, 0, window_start)
    local count = redis.call('ZCARD', key)
    
    if count >= max_exec then
        return 0
    end
    
    redis.call('ZADD', key, now, job_id)
    redis.call('EXPIRE', key, 86400)
    return 1
    """
    
    script = redis.register_script(lua_script)
    job_id = f"{payload.tenant_id}:{now}:{job_data.app_name}"
    allowed = await script(keys=[key], args=[payload.max_executions_per_24h, now, window_start, job_id])
    
    if not allowed:
        raise HTTPException(
            status_code=429,
            detail=f"Max executions per 24h ({payload.max_executions_per_24h}) reached"
        )
    
    return JobStartResponse(success=True, message="Job started")