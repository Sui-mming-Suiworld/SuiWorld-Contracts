from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_galleries():
    # TODO: Return list of predefined galleries (Degen, Dev)
    return []

@router.get("/{slug}")
def get_gallery_details(slug: str):
    # TODO: Return details for a specific gallery
    return {"slug": slug}
