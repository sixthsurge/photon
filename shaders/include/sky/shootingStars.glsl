// Shooting stars implementation based on https://www.shadertoy.com/view/ttVXDy and also based on https://github.com/OUdefie17/Photon-GAMS

#define S(a,b,t) smoothstep(a,b,t)

float N21(vec2 p) {
    p = fract(p*vec2(233.34, 851.73));
    p += dot(p, p+23.45);
    return fract(p.x * p.y);
}

float DistLine(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p-a;
    vec2 ba = b-a;
    float t = clamp(dot(pa, ba)/ dot(ba, ba), 0.0, 1.0);
    return length(pa - ba*t);
}

float DrawLine(vec2 p, vec2 a, vec2 b) {
    float d = DistLine(p, a, b);
    float m = S(SHOOTING_STARS_LINE_THICKNESS, 0.00001, d);
    float d2 = length(a-b);
    m *= S(1.0, 0.5, d2) + S(0.04, 0.03, abs(d2-0.75));
    return m;
}

float ShootingStar(vec2 uv, vec2 startPos, vec2 direction) {    
    vec2 gv = fract(uv)-0.5;
    vec2 id = floor(uv);
    
    float h = N21(id);
    
    if (h > SHOOTING_STARS_DENSITY) return 0.0;
    
    float line = DrawLine(gv, startPos, startPos + direction * SHOOTING_STARS_TRAIL_LENGTH);
    float trail = S(SHOOTING_STARS_TRAIL_FADE, 0.0, dot(gv - startPos, normalize(direction)));
	
    return line * trail;
}

vec3 DrawShootingStars(vec3 color, vec3 worldPosition) {
    #ifndef SHOOTING_STARS
    return color;
    #endif

    float visibility = 0.0;

    #ifdef WORLD_OVERWORLD
    float nightFactor = smoothstep(0.0, 0.1, -sun_dir.y);
    visibility = nightFactor * (1.0 - rainStrength);
    #endif

    if (visibility <= 0.0) return color;

    vec2 uv = worldPosition.xz / worldPosition.y;
    uv *= SHOOTING_STARS_ZOOM;
    
    float t = frameTimeCounter * SHOOTING_STARS_SPEED;

    vec2 startPositions[20] = vec2[](
        vec2(-0.4, 0.3),
        vec2(0.2, 0.4),
        vec2(-0.1, -0.3),
        vec2(0.3, -0.2),
        vec2(-0.3, 0.1),
        vec2(0.5, 0.2),
        vec2(-0.5, -0.1),
        vec2(0.1, 0.5),
        vec2(-0.2, -0.4),
        vec2(0.4, -0.3),
        vec2(0.6, 0.1),
        vec2(-0.6, 0.4),
        vec2(0.3, -0.5),
        vec2(-0.4, -0.2),
        vec2(0.2, 0.6),
        vec2(-0.1, -0.6),
        vec2(0.5, -0.4),
        vec2(-0.3, 0.5),
        vec2(0.7, 0.3),
        vec2(-0.7, -0.3)
    );

    vec2 directions[20] = vec2[](
        normalize(vec2(0.7, 0.7)),
        normalize(vec2(0.7, -0.7)),
        normalize(vec2(-0.7, 0.0)),
        normalize(vec2(0.7, 0.0)),
        normalize(vec2(0.5, 0.8)),
        normalize(vec2(-0.6, 0.8)),
        normalize(vec2(0.9, -0.4)),
        normalize(vec2(-0.8, -0.6)),
        normalize(vec2(0.3, 0.95)),
        normalize(vec2(-0.2, -0.98)),
        normalize(vec2(0.8, 0.6)),
        normalize(vec2(-0.9, 0.4)),
        normalize(vec2(0.5, -0.9)),
        normalize(vec2(-0.4, 0.9)),
        normalize(vec2(0.2, 0.98)),
        normalize(vec2(-0.3, -0.95)),
        normalize(vec2(0.95, -0.3)),
        normalize(vec2(-0.7, 0.7)),
        normalize(vec2(0.6, -0.8)),
        normalize(vec2(-0.5, -0.85))
    );

    float stars = 0.0;
    for (int i = 0; i < SHOOTING_STARS_COUNT; i++) {
        vec2 offsetUV = uv + t * directions[i] * (0.8 + 0.4 * float(i) / float(SHOOTING_STARS_COUNT));
        stars += ShootingStar(offsetUV, startPositions[i], directions[i]);
    }

    vec3 shootingStars = vec3(clamp(stars, 0.0, 1.0));
    
    // Apply atmosphere transmittance to shooting stars
    if (stars > 0.0) {
        vec3 ray_dir = normalize(worldPosition); 
        vec3 ray_origin = vec3(0.0, planet_radius, 0.0);
        vec3 transmittance = atmosphere_transmittance(ray_origin, ray_dir);
        
        // Apply transmittance to shooting stars
        shootingStars *= transmittance;
    }
    
    return color + shootingStars * visibility;
}