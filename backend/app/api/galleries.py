from fastapi import APIRouter, HTTPException, status

router = APIRouter()


@router.get("/")
def get_galleries():
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Galleries have been retired. Use the home feed instead.",
    )


@router.get("/{slug}")
def get_gallery_details(slug: str):
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="Gallery detail pages are no longer available.",
    )
