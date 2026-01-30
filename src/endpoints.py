import time
import warnings
from asyncio import wait_for
from email.utils import parsedate_to_datetime
from http import HTTPStatus
from http.cookies import SimpleCookie
from typing import Annotated
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from playwright_captcha import CaptchaType

from src.consts import CHALLENGE_TITLES
from src.models import (
    HealthcheckResponse,
    LinkRequest,
    LinkResponse,
    Solution,
)
from src.utils import CamoufoxDepClass, TimeoutTimer, get_camoufox, logger

warnings.filterwarnings("ignore", category=SyntaxWarning)


router = APIRouter()

CamoufoxDep = Annotated[CamoufoxDepClass, Depends(get_camoufox)]


def _parse_set_cookie(set_cookie_header: str | None, fallback_url: str) -> list[dict]:
    if not set_cookie_header:
        return []

    cookie_jar: SimpleCookie[str] = SimpleCookie()
    try:
        cookie_jar.load(set_cookie_header)
    except Exception:
        for part in [c.strip() for c in set_cookie_header.split("\n") if c.strip()]:
            try:
                cookie_jar.load(part)
            except Exception:
                continue

    parsed_url = urlparse(fallback_url)
    fallback_domain = parsed_url.hostname or ""

    parsed_cookies: list[dict] = []
    for name, morsel in cookie_jar.items():
        domain = morsel["domain"] or fallback_domain
        path = morsel["path"] or "/"
        expires = -1
        if morsel["expires"]:
            try:
                expires_dt = parsedate_to_datetime(morsel["expires"])
                expires = int(expires_dt.timestamp())
            except Exception:
                expires = -1

        http_only = bool(morsel["httponly"]) if morsel["httponly"] else False
        secure = bool(morsel["secure"]) if morsel["secure"] else False
        same_site = morsel["samesite"] or None

        parsed_cookies.append(
            {
                "name": name,
                "value": morsel.value,
                "domain": domain,
                "path": path,
                "expires": expires,
                "httpOnly": http_only,
                "secure": secure,
                "sameSite": same_site,
                "size": len(name) + len(morsel.value),
                "session": expires == -1,
            }
        )

    return parsed_cookies


@router.get("/", include_in_schema=False)
def read_root():
    """Redirect to /docs."""
    logger.debug("Redirecting to /docs")
    return RedirectResponse(url="/docs", status_code=301)


@router.get("/health")
async def health_check(sb: CamoufoxDep):
    """Health check endpoint."""
    health_check_request = await read_item(
        LinkRequest.model_construct(url="https://google.com"),
        sb,
    )

    if health_check_request.solution.status != HTTPStatus.OK:
        raise HTTPException(
            status_code=500,
            detail="Health check failed",
        )

    return HealthcheckResponse(user_agent=health_check_request.solution.user_agent)


@router.post("/v1")
async def read_item(request: LinkRequest, dep: CamoufoxDep) -> LinkResponse:
    """Handle POST requests."""
    start_time = int(time.time() * 1000)

    timer = TimeoutTimer(duration=request.max_timeout)

    request.url = request.url.replace('"', "").strip()
    try:
        page_request = await dep.page.goto(
            request.url, timeout=timer.remaining() * 1000
        )
        status = page_request.status if page_request else HTTPStatus.OK
        await dep.page.wait_for_load_state(
            state="domcontentloaded", timeout=timer.remaining() * 1000
        )
        await dep.page.wait_for_load_state(
            "networkidle", timeout=timer.remaining() * 1000
        )

        if await dep.page.title() in CHALLENGE_TITLES:
            logger.info("Challenge detected, attempting to solve...")
            # Solve the captcha
            await wait_for(
                dep.solver.solve_captcha(  # pyright: ignore[reportUnknownMemberType,reportUnknownArgumentType]
                    captcha_container=dep.page,
                    captcha_type=CaptchaType.CLOUDFLARE_INTERSTITIAL,
                    wait_checkbox_attempts=1,
                    wait_checkbox_delay=0.5,
                ),
                timeout=timer.remaining(),
            )
            status = HTTPStatus.OK
            logger.debug("Challenge solved successfully.")
    except TimeoutError as e:
        logger.error("Timed out while solving the challenge")
        raise HTTPException(
            status_code=408,
            detail="Timed out while solving the challenge",
        ) from e

    cookies = await dep.context.cookies()
    set_cookie_header = None
    if page_request:
        set_cookie_header = page_request.headers.get("set-cookie")

    parsed_header_cookies = _parse_set_cookie(set_cookie_header, dep.page.url)
    if parsed_header_cookies:
        cookie_index = {
            (cookie.get("name"), cookie.get("domain"), cookie.get("path")): cookie
            for cookie in cookies
        }
        for header_cookie in parsed_header_cookies:
            key = (
                header_cookie.get("name"),
                header_cookie.get("domain"),
                header_cookie.get("path"),
            )
            cookie_index[key] = header_cookie
        cookies = list(cookie_index.values())

    # Capture raw HTTP response body instead of rendered HTML
    # This fixes the issue where page.content() returns browser-rendered HTML
    # including wrapper tags like <html><body><pre>JSON</pre></body></html>
    # For FlareSolverr compatibility, we need the raw response body
    response_body = ""
    if page_request:
        try:
            response_body = await page_request.text()
        except Exception as e:
            logger.warning(f"Failed to get response text, falling back to page content: {e}")
            response_body = await dep.page.content()
    else:
        response_body = await dep.page.content()

    return LinkResponse(
        message="Success",
        solution=Solution(
            user_agent=await dep.page.evaluate("navigator.userAgent"),
            url=dep.page.url,
            status=status,
            cookies=cookies,
            headers=page_request.headers if page_request else {},
            response=response_body,
        ),
        start_timestamp=start_time,
    )
