// This file is distributed under the MIT license.
// See the LICENSE file for details.

#include "render.h"

namespace visionaray
{

void render_cu(
        cuda_volume_ref_t const&        volume,
        aabb                            bbox,
        vec2f                           value_range,
        host_device_rt&                 rt,
        cuda_sched<ray_type_gpu>&       sched,
        camera_t const&                 cam,
        float                           delta
        )
{
    auto sparams = make_sched_params(
            cam,
            rt
            );

    auto range = value_range.y - value_range.x;

    using R = ray_type_gpu;
    using S = R::scalar_type;
    using C = vector<4, S>;

    sched.frame([=] __device__ (R ray, int x, int y) -> result_record<S>
    {
        result_record<S> result;

        //bool debug = (x == 256) && (y == 256);
        //bool crosshair = (x == 256) || (y == 256);
        //if (crosshair) {result.color = C(1.f, 1.f, 1.f, 1.f); result.hit = true; return result;}

        auto hit_rec = intersect(ray, bbox);
        auto t = hit_rec.tnear;

        result.color = C(0.0);
        float line_integral = 0.0f;

        while ( any(t < hit_rec.tfar) )
        {
            auto pos = ray.ori + ray.dir * t;
            auto tex_coord = vector<3, S>(
                    ( pos.x + (bbox.size().x / 2) ) / bbox.size().x,
                    (-pos.y + (bbox.size().y / 2) ) / bbox.size().y,
                    (-pos.z + (bbox.size().z / 2) ) / bbox.size().z
                    );

            // sample volume and do post-classification
            auto voxel = tex3D(volume, tex_coord);
            float voxel_norm = ((float)voxel - value_range.x) / range;
            line_integral += select(
                    t< hit_rec.tfar,
                    voxel_norm,
                    0.f
                    ) * delta * 0.001f;

            // step on
            t += delta;
        }

        result.color = C(clamp(line_integral, 0.f, 1.f));

        result.hit = hit_rec.hit;
        return result;
    }, sparams);
}

} // visionaray
