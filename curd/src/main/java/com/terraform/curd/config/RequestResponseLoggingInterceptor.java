package com.terraform.curd.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Logs basic request/response metadata for every inbound HTTP call using SLF4J.
 *
 * <p>A correlation timestamp is stored on the request as an attribute so the elapsed
 * processing time can be reported once the response completes.</p>
 */
@Slf4j
@Component
public class RequestResponseLoggingInterceptor implements HandlerInterceptor {

    private static final String START_TIME_ATTRIBUTE = "requestStartTime";

    @Override
    public boolean preHandle(@NonNull HttpServletRequest request,
                             @NonNull HttpServletResponse response,
                             @NonNull Object handler) {
        request.setAttribute(START_TIME_ATTRIBUTE, System.currentTimeMillis());
        log.info("Incoming request: {} {}{}",
                request.getMethod(),
                request.getRequestURI(),
                request.getQueryString() == null ? "" : "?" + request.getQueryString());
        return true;
    }

    @Override
    public void afterCompletion(@NonNull HttpServletRequest request,
                                @NonNull HttpServletResponse response,
                                @NonNull Object handler,
                                Exception ex) {
        Object startTime = request.getAttribute(START_TIME_ATTRIBUTE);
        long elapsed = startTime == null ? -1 : System.currentTimeMillis() - (long) startTime;
        log.info("Completed request: {} {} -> status={} ({} ms)",
                request.getMethod(),
                request.getRequestURI(),
                response.getStatus(),
                elapsed);
    }
}
