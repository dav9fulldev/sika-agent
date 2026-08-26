from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel

from ..database import get_db
from ..services.auth_service import get_current_user
from ..models.user import UserModel
from ..models.payment_method import PaymentMethodModel

router = APIRouter(
    prefix="/api/v1/users",
    tags=["Users"]
)

class UserUpdate(BaseModel):
    name: str = None
    phone: str = None

class PaymentMethodCreate(BaseModel):
    type: str
    title: str
    subtitle: str
    is_default: bool = False

@router.put("/me")
async def update_user(
    update_data: UserUpdate,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if update_data.name:
        current_user.full_name = update_data.name
    if update_data.phone:
        current_user.phone = update_data.phone
        
    db.commit()
    db.refresh(current_user)
    return {"message": "User updated", "user": {"name": current_user.full_name, "phone": current_user.phone}}

@router.post("/me/kyc")
async def submit_kyc(
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    current_user.is_kyc_verified = True
    db.commit()
    return {"message": "KYC verified successfully"}

@router.get("/me/payment-methods")
async def get_payment_methods(
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    methods = db.query(PaymentMethodModel).filter(PaymentMethodModel.user_id == current_user.id).all()
    return [
        {
            "id": str(m.id),
            "type": m.type,
            "title": m.title,
            "subtitle": m.subtitle,
            "is_default": m.is_default
        } for m in methods
    ]

@router.post("/me/payment-methods")
async def add_payment_method(
    method_data: PaymentMethodCreate,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # If new method is default, remove default from others
    if method_data.is_default:
        db.query(PaymentMethodModel).filter(PaymentMethodModel.user_id == current_user.id).update({"is_default": False})
    
    # If it's the first method, make it default automatically
    existing = db.query(PaymentMethodModel).filter(PaymentMethodModel.user_id == current_user.id).first()
    is_default = method_data.is_default if existing else True

    new_method = PaymentMethodModel(
        user_id=current_user.id,
        type=method_data.type,
        title=method_data.title,
        subtitle=method_data.subtitle,
        is_default=is_default
    )
    db.add(new_method)
    db.commit()
    db.refresh(new_method)
    
    return {
        "id": str(new_method.id),
        "type": new_method.type,
        "title": new_method.title,
        "subtitle": new_method.subtitle,
        "is_default": new_method.is_default
    }

@router.delete("/me/payment-methods/{method_id}")
async def delete_payment_method(
    method_id: int,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    method = db.query(PaymentMethodModel).filter(
        PaymentMethodModel.id == method_id,
        PaymentMethodModel.user_id == current_user.id
    ).first()
    
    if not method:
        raise HTTPException(status_code=404, detail="Payment method not found")
        
    db.delete(method)
    db.commit()
    return {"message": "Payment method deleted"}

@router.put("/me/payment-methods/{method_id}/default")
async def set_default_payment_method(
    method_id: int,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    method = db.query(PaymentMethodModel).filter(
        PaymentMethodModel.id == method_id,
        PaymentMethodModel.user_id == current_user.id
    ).first()
    
    if not method:
        raise HTTPException(status_code=404, detail="Payment method not found")
        
    db.query(PaymentMethodModel).filter(PaymentMethodModel.user_id == current_user.id).update({"is_default": False})
    method.is_default = True
    db.commit()
    return {"message": "Default payment method updated"}
