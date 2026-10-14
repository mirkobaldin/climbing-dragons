# Anteprime dei modelli della sessione cloud (docs/CLOUD_SESSIONE.md, sezione 3): Eevee con cielo e
# sole, JPG 1280x720 sotto 400 KB in cloud/<Nome>/anteprime/, manichini di 1,7 m per la scala.

import math
import os
import time

import bpy
from mathutils import Vector

import cloud_lib as L


def umano(coll, x, y, z, rot=0.0):
    """manichino di 1,7 m (non esportato)"""
    mat = bpy.data.materials.get("Umano") or bpy.data.materials.new("Umano")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.65, 0.18, 0.12, 1)
    parts = [((-0.1, 0, 0.42), (0.08, 0.08, 0.42)), ((0.1, 0, 0.42), (0.08, 0.08, 0.42)),
             ((0, 0, 1.12), (0.2, 0.12, 0.32)), ((-0.27, 0, 1.08), (0.06, 0.06, 0.3)), ((0.27, 0, 1.08), (0.06, 0.06, 0.3)),
             ((0, 0, 1.58), (0.11, 0.11, 0.12))]
    c, s = math.cos(rot), math.sin(rot)
    for (dx, dy, dz), (sx, sy, sz) in parts:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(x + c * dx - s * dy, y + s * dx + c * dy, z + dz))
        o = bpy.context.active_object
        o.scale = (sx, sy, sz)
        o.rotation_euler = (0, 0, rot)
        o.data.materials.append(mat)
        for cl in list(o.users_collection):
            cl.objects.unlink(o)
        coll.objects.link(o)


def render(name, views, umani=(), ground=None, sun_rot=-35, quality=82, samples=32):
    """views: {nome: (camera, bersaglio, focale)}; ground: (centro, lato, colore) per un piano sotto"""
    out = os.path.join(L.CLOUD, name, "anteprime")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Cielo")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    sky = nt.nodes.new("ShaderNodeTexSky")
    for st in ("MULTIPLE_SCATTERING", "NISHITA"):
        try:
            sky.sky_type = st
            break
        except Exception:
            pass
    try:
        sky.sun_elevation = math.radians(32)
        sky.sun_rotation = math.radians(215)
    except Exception:
        pass
    nt.links.new(sky.outputs["Color"], nt.nodes["Background"].inputs["Color"])
    nt.nodes["Background"].inputs["Strength"].default_value = 0.3
    sun = bpy.data.objects.new("Sole", bpy.data.lights.new("Sole", "SUN"))
    sun.data.energy = 3.6
    sun.data.color = (1.0, 0.92, 0.8)
    sun.data.angle = math.radians(1.5)
    sun.rotation_euler = (math.radians(55), 0, math.radians(sun_rot))
    scene.collection.objects.link(sun)
    coll = bpy.data.collections.new("Umani")
    scene.collection.children.link(coll)
    for u in umani:
        umano(coll, *u)
    if ground:
        c, size, colr = ground
        gm = bpy.data.materials.new("Terreno")
        gm.use_nodes = True
        b = gm.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*colr, 1)
        b.inputs["Roughness"].default_value = 1.0
        bpy.ops.mesh.primitive_plane_add(size=size, location=c)
        bpy.context.active_object.data.materials.append(gm)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.clip_start = 0.05
    cam.data.clip_end = 6000
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = samples
    except Exception:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = quality
    # "Standard" come in Roblox (AgX spegneva i colori nelle anteprime)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.15
    only = os.environ.get("VISTE")
    done = []
    for vn, (pos, target, lens) in views.items():
        if only and vn not in only.split(","):
            continue
        cam.location = pos
        cam.data.lens = lens
        d = (Vector(target) - Vector(pos)).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out, "%s_%s.jpg" % (name, vn))
        scene.render.filepath = path
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        kb = os.path.getsize(path) // 1024
        print("  anteprima %s (%.0fs, %d KB)" % (vn, time.time() - t0, kb), flush=True)
        done.append(path)
    return done


def sagome(name, objs, views):
    """sagome nere su cielo chiaro (fase 2 del metodo)"""
    out = os.path.join(L.CLOUD, name, "anteprime")
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    world = bpy.data.worlds.new("Bianco")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.85, 0.9, 1.0, 1)
    scene.world = world
    black = bpy.data.materials.new("Nero")
    black.use_nodes = True
    bs = black.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bs.inputs["Roughness"].default_value = 1.0
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(black)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.clip_end = 5000
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.quality = 85
    scene.view_settings.view_transform = "Standard"
    for vn, (pos, target, lens) in views.items():
        cam.location = pos
        cam.data.lens = lens
        d = (Vector(target) - Vector(pos)).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, "sagoma_%s.jpg" % vn)
        bpy.ops.render.render(write_still=True)
