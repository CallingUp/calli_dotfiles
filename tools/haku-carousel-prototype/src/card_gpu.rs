//! Bounded, persistent texture cache and two-triangle card rendering.
//! No new GPU device, render pass, event loop or image decoding is introduced.
use iced::advanced::image::Id;
use iced::widget::{image::Handle, shader};
use iced::{Color, Rectangle, mouse, wgpu};
use std::{
    collections::HashMap,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
};

static TEXTURES: AtomicUsize = AtomicUsize::new(0);
static UPLOADS: AtomicUsize = AtomicUsize::new(0);
pub fn metrics() -> (usize, usize) {
    (
        TEXTURES.load(Ordering::Relaxed),
        UPLOADS.load(Ordering::Relaxed),
    )
}

#[derive(Clone, Debug)]
pub struct Card {
    pub slot: usize,
    pub rect: Rectangle,
    pub clip: Rectangle,
    pub image: Rectangle,
    pub radius: f32,
    pub opacity: f32,
    pub selected: bool,
    pub accent: Color,
    pub background: Color,
    pub texture: Option<Handle>,
    pub live: Arc<[Id]>,
}
impl<Message> shader::Program<Message> for Card {
    type State = ();
    type Primitive = Card;
    fn draw(&self, _: &(), _: mouse::Cursor, _: Rectangle) -> Card {
        self.clone()
    }
}

const UNIFORM_SIZE: usize = 7 * 16;
fn rectangle(r: Rectangle) -> [f32; 4] {
    [r.x, r.y, r.width, r.height]
}
fn encode(rows: [[f32; 4]; 7]) -> [u8; UNIFORM_SIZE] {
    let mut bytes = [0; UNIFORM_SIZE];
    for (i, value) in rows.into_iter().flatten().enumerate() {
        bytes[i * 4..i * 4 + 4].copy_from_slice(&value.to_ne_bytes());
    }
    bytes
}
struct Slot {
    buffer: wgpu::Buffer,
    group: wgpu::BindGroup,
    previous: Option<[u8; UNIFORM_SIZE]>,
}
struct Texture {
    _texture: wgpu::Texture,
    group: wgpu::BindGroup,
}
pub struct Pipeline {
    render: wgpu::RenderPipeline,
    texture_layout: wgpu::BindGroupLayout,
    sampler: wgpu::Sampler,
    slots: [Slot; 7],
    textures: HashMap<Id, Texture>,
    fallback: Texture,
}
fn upload(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    layout: &wgpu::BindGroupLayout,
    sampler: &wgpu::Sampler,
    width: u32,
    height: u32,
    pixels: &[u8],
) -> Texture {
    let size = wgpu::Extent3d {
        width,
        height,
        depth_or_array_layers: 1,
    };
    let texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("carousel thumbnail"),
        size,
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8UnormSrgb,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });
    queue.write_texture(
        wgpu::TexelCopyTextureInfo {
            texture: &texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        pixels,
        wgpu::TexelCopyBufferLayout {
            offset: 0,
            bytes_per_row: Some(width * 4),
            rows_per_image: Some(height),
        },
        size,
    );
    let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
    let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: Some("carousel thumbnail binding"),
        layout,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(&view),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: wgpu::BindingResource::Sampler(sampler),
            },
        ],
    });
    Texture {
        _texture: texture,
        group,
    }
}
impl shader::Pipeline for Pipeline {
    fn new(device: &wgpu::Device, queue: &wgpu::Queue, format: wgpu::TextureFormat) -> Self {
        let uniforms = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("carousel card uniforms"),
            entries: &[wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });
        let texture_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("carousel texture layout"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });
        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("carousel linear sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });
        let layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("carousel card pipeline"),
            bind_group_layouts: &[&uniforms, &texture_layout],
            push_constant_ranges: &[],
        });
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("carousel card shader"),
            source: wgpu::ShaderSource::Wgsl(include_str!("card_gpu.wgsl").into()),
        });
        let render = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("carousel two-triangle cards"),
            layout: Some(&layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vertex_main"),
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fragment_main"),
                targets: &[Some(wgpu::ColorTargetState {
                    format,
                    blend: Some(wgpu::BlendState::PREMULTIPLIED_ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });
        let slots = std::array::from_fn(|_| {
            let buffer = device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("carousel card transform"),
                size: UNIFORM_SIZE as u64,
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            });
            let group = device.create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("carousel card transform binding"),
                layout: &uniforms,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: buffer.as_entire_binding(),
                }],
            });
            Slot {
                buffer,
                group,
                previous: None,
            }
        });
        let fallback = upload(
            device,
            queue,
            &texture_layout,
            &sampler,
            1,
            1,
            &[255, 255, 255, 255],
        );
        Self {
            render,
            texture_layout,
            sampler,
            slots,
            textures: HashMap::new(),
            fallback,
        }
    }
}
impl shader::Primitive for Card {
    type Pipeline = Pipeline;
    fn prepare(
        &self,
        pipeline: &mut Pipeline,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        bounds: &Rectangle,
        _: &shader::Viewport,
    ) {
        pipeline.textures.retain(|id, _| self.live.contains(id));
        if let Some(Handle::Rgba {
            id,
            width,
            height,
            pixels,
        }) = &self.texture
        {
            pipeline.textures.entry(*id).or_insert_with(|| {
                UPLOADS.fetch_add(1, Ordering::Relaxed);
                upload(
                    device,
                    queue,
                    &pipeline.texture_layout,
                    &pipeline.sampler,
                    *width,
                    *height,
                    pixels.as_ref(),
                )
            });
        }
        TEXTURES.store(pipeline.textures.len(), Ordering::Relaxed);
        let bytes = encode([
            [bounds.width, bounds.height, bounds.x, bounds.y],
            rectangle(self.rect),
            rectangle(self.clip),
            rectangle(self.image),
            self.accent.into_linear(),
            [
                self.radius,
                self.opacity,
                f32::from(self.selected),
                f32::from(self.texture.is_some()),
            ],
            self.background.into_linear(),
        ]);
        let slot = &mut pipeline.slots[self.slot];
        if slot.previous != Some(bytes) {
            queue.write_buffer(&slot.buffer, 0, &bytes);
            slot.previous = Some(bytes);
        }
    }
    fn draw(&self, pipeline: &Pipeline, pass: &mut wgpu::RenderPass<'_>) -> bool {
        let texture = self
            .texture
            .as_ref()
            .and_then(|h| pipeline.textures.get(&h.id()))
            .unwrap_or(&pipeline.fallback);
        pass.set_pipeline(&pipeline.render);
        pass.set_bind_group(0, &pipeline.slots[self.slot].group, &[]);
        pass.set_bind_group(1, &texture.group, &[]);
        pass.draw(0..6, 0..1);
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn uniform_has_wgsl_alignment() {
        let bytes = encode([[1., 2., 3., 4.]; 7]);
        assert_eq!(bytes.len(), 112);
        assert_eq!(f32::from_ne_bytes(bytes[108..112].try_into().unwrap()), 4.);
    }
    #[test]
    fn seven_consecutive_slots_do_not_alias() {
        for center in [-100, -1, 0, 1, 100] {
            let mut slots: Vec<_> = (center - 3..=center + 3)
                .map(|i: i64| i.rem_euclid(7))
                .collect();
            slots.sort();
            assert_eq!(slots, vec![0, 1, 2, 3, 4, 5, 6]);
        }
    }
}
