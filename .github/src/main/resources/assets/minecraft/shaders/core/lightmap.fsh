#version 150

uniform float AmbientLightFactor;
uniform float SkyFactor;
uniform float BlockFactor;
uniform int UseBrightLightmap;
uniform vec3 SkyLightColor;
uniform float NightVisionFactor;
uniform float DarknessScale;
uniform float DarkenWorldFactor;
uniform float BrightnessFactor;

in vec2 texCoord;
out vec4 fragColor;

float get_brightness(float level) {
    float curved_level = level / (4.0 - 3.0 * level);
    return mix(curved_level, 1.0, AmbientLightFactor);
}

// Thuật toán ACES Filmic Tonemapping (Tạo độ rực và tương phản kiểu Solar Shader)
vec3 aces_tonemap(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    float block_brightness = get_brightness(floor(texCoord.x * 16.0) / 15.0) * BlockFactor;
    float sky_brightness = get_brightness(floor(texCoord.y * 16.0) / 15.0) * SkyFactor;

    // 1. Ánh sáng Block (Đuốc, Đèn lồng, Glowstone): Màu cam hổ phách ấm áp kiểu Solas/Solar
    float torch_curve = pow(block_brightness, 1.35);
    vec3 warm_torch = vec3(
        torch_curve * 1.35,
        pow(torch_curve, 1.45) * 0.82,
        pow(torch_curve, 2.20) * 0.35
    );

    // 2. Ánh sáng Bầu trời (Nắng vàng ban ngày + Ánh trăng xanh điện ảnh ban đêm)
    vec3 solar_day_tint = vec3(1.12, 1.02, 0.90); // Nắng ấm
    vec3 night_moon_tint = vec3(0.08, 0.14, 0.28); // Trăng xanh dịu mắt
    
    // Chuyển màu mượt giữa ngày và đêm dựa theo SkyFactor
    float day_amount = clamp((SkyFactor - 0.15) / 0.85, 0.0, 1.0);
    vec3 custom_sky_color = mix(night_moon_tint, SkyLightColor * solar_day_tint, day_amount);
    vec3 sky_light = custom_sky_color * sky_brightness;

    // 3. Hòa trộn ánh sáng môi trường tối thiểu (Giúp hang động có chiều sâu nhưng không bị mù)
    vec3 ambient_floor = vec3(0.025, 0.03, 0.045);
    vec3 color = max(warm_torch, sky_light) + ambient_floor;

    // Hiệu ứng bão/tối thế giới của Wither
    if (UseBrightLightmap == 0) {
        color = mix(color, vec3(0.75, 0.65, 0.55), DarkenWorldFactor * 0.35);
    }

    // Hiệu ứng Night Vision
    if (NightVisionFactor > 0.0) {
        float max_comp = max(color.r, max(color.g, color.b));
        if (max_comp < 1.0 && max_comp > 0.0) {
            color = mix(color, color / max_comp, NightVisionFactor);
        }
    }

    // 4. Áp dụng Tonemapping & Contrast S-Curve của Shader
    color = aces_tonemap(color * 1.18);
    
    // Cân chỉnh Gamma theo thanh kéo Brightness trong cài đặt game
    vec3 not_gamma = pow(color, vec3(0.85));
    color = mix(color, not_gamma, BrightnessFactor * 0.65);
    color = clamp(color - vec3(DarknessScale), 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
