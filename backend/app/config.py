from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Configuracao lida exclusivamente de variaveis de ambiente (.env em dev).
    Nunca hardcode secret aqui - regra 1 de SDP_SEGURANCA.md.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str

    session_cookie_name: str = "sdp_session"
    session_ttl_minutos: int = 30
    session_cookie_secure: bool = True  # so False em dev local sem HTTPS

    login_max_tentativas: int = 5
    login_janela_segundos: int = 300

    app_env: str = "development"


settings = Settings()
