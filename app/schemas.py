from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class LicenseStatus(str):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    EXPIRED = "EXPIRED"

class LicenseCreate(BaseModel):
    tenant_id: str
    max_apps: int = Field(..., ge=1)
    max_executions_per_24h: int = Field(..., ge=1)
    valid_from: datetime
    valid_to: datetime
    status: str = LicenseStatus.ACTIVE

class LicenseTokenPayload(BaseModel):
    tenant_id: str
    max_apps: int
    max_executions_per_24h: int
    valid_from: datetime
    valid_to: datetime
    status: str
    exp: int
    iat: int

class AppRegistrationRequest(BaseModel):
    app_name: str = Field(..., min_length=1, max_length=255)

class AppRegistrationResponse(BaseModel):
    success: bool
    message: str
    app_id: Optional[int] = None

class JobStartRequest(BaseModel):
    app_name: str = Field(..., min_length=1, max_length=255)

class JobStartResponse(BaseModel):
    success: bool
    message: str