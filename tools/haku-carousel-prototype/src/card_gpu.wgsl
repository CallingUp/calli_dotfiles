struct Card {
    screen: vec4<f32>,
    rect: vec4<f32>,
    clip: vec4<f32>,
    image: vec4<f32>,
    accent: vec4<f32>,
    params: vec4<f32>, // radius, opacity, selected, has texture
    background: vec4<f32>,
};
@group(0) @binding(0) var<uniform> card: Card;
@group(1) @binding(0) var thumbnail: texture_2d<f32>;
@group(1) @binding(1) var thumbnail_sampler: sampler;

struct Vertex {
    @builtin(position) position: vec4<f32>,
    @location(0) point: vec2<f32>,
};
@vertex fn vertex_main(@builtin(vertex_index) index: u32) -> Vertex {
    let corners = array<vec2<f32>, 6>(
        vec2(0., 0.), vec2(1., 0.), vec2(0., 1.),
        vec2(0., 1.), vec2(1., 0.), vec2(1., 1.)
    );
    // Two triangles; analytic antialiasing includes the stroke's outer edge.
    let point = card.rect.xy - vec2(2.) + corners[index] * (card.rect.zw + vec2(4.));
    let ndc = (point - card.screen.zw) / card.screen.xy * 2. - vec2(1.);
    var out: Vertex;
    out.position = vec4(ndc.x, -ndc.y, 0., 1.);
    out.point = point;
    return out;
}
@fragment fn fragment_main(vertex: Vertex) -> @location(0) vec4<f32> {
    let p = vertex.point;
    let q = abs(p - card.rect.xy - card.rect.zw * .5)
        - (card.rect.zw * .5 - vec2(card.params.x));
    let distance = length(max(q, vec2(0.))) + min(max(q.x, q.y), 0.) - card.params.x;
    let aa = max(fwidth(distance), .001);
    if any(p < card.clip.xy) || any(p >= card.clip.xy + card.clip.zw) { discard; }
    let selected = card.params.z > .5;
    let coverage = 1. - smoothstep(-aa * .5, aa * .5, distance - select(0., 1., selected));
    if coverage <= 0. { discard; }
    var color = card.background.rgb;
    var alpha = coverage * card.params.y;
    if selected && distance > -1. {
        // The old Canvas stroke was opaque, even while the card was moving.
        color = card.accent.rgb;
        alpha = coverage;
    }
    var result = vec4(color * alpha, alpha);
    if card.params.w > .5 && all(p >= card.image.xy) && all(p < card.image.xy + card.image.zw) {
        let dimensions = vec2<f32>(textureDimensions(thumbnail));
        let cover = max(card.image.z / dimensions.x, card.image.w / dimensions.y);
        let uv = (p - card.image.xy - card.image.zw * .5) / (dimensions * cover) + vec2(.5);
        let sample_color = textureSampleLevel(thumbnail, thumbnail_sampler, uv, 0.);
        let image_alpha = sample_color.a * card.params.y;
        // Same ordering as Canvas: image with opacity over the translucent card.
        result = vec4(sample_color.rgb * image_alpha, image_alpha) + result * (1. - image_alpha);
    }
    return result;
}
