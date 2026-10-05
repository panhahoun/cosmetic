import os

from app.main import app

if __name__ == "__main__":
    import uvicorn

    # Reload forks a supervisor process and restarts on any file write. Never
    # enable it outside local development.
    uvicorn.run(
        "app.main:app",
        host=os.getenv("HOST", "127.0.0.1"),
        port=int(os.getenv("PORT", "8000")),
        reload=os.getenv("ENV", "dev") == "dev",
    )
