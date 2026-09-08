from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    senha: str


class LoginResponse(BaseModel):
    usuario_id: int
    papeis: list[str]


class UsuarioAutenticado(BaseModel):
    id: int
    email: str
    papeis: list[str]
