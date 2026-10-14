# Cottura dei materiali (docs/CLOUD_SESSIONE.md 2.5): per un pezzo crea una UV unica ("Bake")
# e cuoce con Cycles, a partire dal materiale ripetuto (texture di cloud_lib sulla UV "Tile"):
#   colore = pietra * tinta del blocco (attributo "Tinta") * ombra nelle fessure (AO)
#            + spigoli consumati piu' chiari (pointiness) + sporco e colature in basso
#            + muschio sulle superfici rivolte in su
#   normali = grana del materiale ripetuto (tangenti, sulla UV unica)
#   rugosita' = dal materiale ripetuto, piu' liscia sugli spigoli consumati
# Pezzi uguali (gli 8 lati dell'arena) cuociono una volta: share_bake copia UV e materiale.

import os
import time

import bpy

import cloud_lib as L


def _uv_unique(ob, margin=0.004):
    me = ob.data
    if me.uv_layers.get("UVMap") and not me.uv_layers.get("Tile"):
        me.uv_layers["UVMap"].name = "Tile"
    bake = me.uv_layers.get("Bake") or me.uv_layers.new(name="Bake")
    me.uv_layers.active = bake
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=margin, area_weight=0.0, correct_aspect=True, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def _source_material(ob, base_mat, texdir, look):
    """materiale di cottura: nodi che compongono colore, rugosita' e normali dal materiale ripetuto"""
    files = L.texture_files(base_mat, texdir)
    m = bpy.data.materials.new("cottura_" + ob.name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new("ShaderNodeOutputMaterial")
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "Tile"

    def img(path, noncolor):
        t = nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(path, check_existing=True)
        if noncolor:
            t.image.colorspace_settings.name = "Non-Color"
        links.new(uv.outputs["UV"], t.inputs["Vector"])
        return t
    col = img(files["BaseColor"], False)
    rough = img(files["Roughness"], True)
    nrm = img(files["Normal"], True)
    # tinta per blocco: +-18% di luminosita' e un po' di caldo/freddo
    attr = nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Tinta"
    tint = nodes.new("ShaderNodeMapRange")
    tint.inputs["To Min"].default_value = 1.0 - look.get("tint", 0.25)
    tint.inputs["To Max"].default_value = 1.0 + look.get("tint", 0.25)
    links.new(attr.outputs["Fac"], tint.inputs["Value"])
    hue = nodes.new("ShaderNodeHueSaturation")
    links.new(col.outputs["Color"], hue.inputs["Color"])
    hsub = nodes.new("ShaderNodeMath")
    hsub.operation = "MULTIPLY_ADD"
    hsub.inputs[1].default_value = 0.03
    hsub.inputs[2].default_value = 0.485
    links.new(attr.outputs["Fac"], hsub.inputs[0])
    links.new(hsub.outputs[0], hue.inputs["Hue"])
    mul = nodes.new("ShaderNodeMixRGB")
    mul.blend_type = "MULTIPLY"
    mul.inputs["Fac"].default_value = 1.0
    links.new(hue.outputs["Color"], mul.inputs["Color1"])
    links.new(tint.outputs["Result"], mul.inputs["Color2"])
    # ombra nelle fessure (AO)
    ao = nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.inputs["Distance"].default_value = look.get("ao_dist", 1.2)
    aoc = nodes.new("ShaderNodeMapRange")
    aoc.inputs["To Min"].default_value = look.get("ao_min", 0.35)
    links.new(ao.outputs["AO"], aoc.inputs["Value"])
    mao = nodes.new("ShaderNodeMixRGB")
    mao.blend_type = "MULTIPLY"
    mao.inputs["Fac"].default_value = 1.0
    links.new(mul.outputs["Color"], mao.inputs["Color1"])
    links.new(aoc.outputs["Result"], mao.inputs["Color2"])
    # spigoli consumati: dove la normale smussata (nodo Bevel) si scosta dalla normale vera
    geo = nodes.new("ShaderNodeNewGeometry")
    bev = nodes.new("ShaderNodeBevel")
    bev.samples = 8
    bev.inputs["Radius"].default_value = look.get("edge_r", 0.06)
    dot = nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    links.new(bev.outputs["Normal"], dot.inputs[0])
    links.new(geo.outputs["Normal"], dot.inputs[1])
    edge = nodes.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.99
    edge.inputs["From Max"].default_value = 0.85
    links.new(dot.outputs["Value"], edge.inputs["Value"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.8
    noise.inputs["Detail"].default_value = 6
    edgen = nodes.new("ShaderNodeMath")
    edgen.operation = "MULTIPLY"
    links.new(edge.outputs["Result"], edgen.inputs[0])
    links.new(noise.outputs["Fac"], edgen.inputs[1])
    wear = nodes.new("ShaderNodeMixRGB")
    wear.blend_type = "SCREEN"
    links.new(edgen.outputs[0], wear.inputs["Fac"])
    links.new(mao.outputs["Color"], wear.inputs["Color1"])
    wear.inputs["Color2"].default_value = (*look.get("wear_col", (0.20, 0.18, 0.16)), 1)
    # sporco e colature: piu' scuro in basso (quota nel pezzo) e a strisce verticali
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], sep.inputs["Vector"])
    zr = nodes.new("ShaderNodeMapRange")
    zr.inputs["From Min"].default_value = look.get("dirt_z0", 0.0)
    zr.inputs["From Max"].default_value = look.get("dirt_z1", 6.0)
    zr.inputs["To Min"].default_value = 1.0
    zr.inputs["To Max"].default_value = 0.0
    links.new(sep.outputs["Z"], zr.inputs["Value"])
    streak = nodes.new("ShaderNodeTexNoise")
    streak.inputs["Scale"].default_value = 1.5
    streak.inputs["Detail"].default_value = 3
    sc = nodes.new("ShaderNodeMapping")
    sc.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
    links.new(geo.outputs["Position"], sc.inputs["Vector"])
    links.new(sc.outputs["Vector"], streak.inputs["Vector"])
    st = nodes.new("ShaderNodeMapRange")
    st.inputs["From Min"].default_value = 0.5
    st.inputs["From Max"].default_value = 0.75
    st.inputs["To Max"].default_value = look.get("streak", 0.35)
    links.new(streak.outputs["Fac"], st.inputs["Value"])
    dsum = nodes.new("ShaderNodeMath")
    dsum.operation = "ADD"
    dsum.use_clamp = True
    zw = nodes.new("ShaderNodeMath")
    zw.operation = "MULTIPLY"
    zw.inputs[1].default_value = look.get("dirt", 0.5)
    links.new(zr.outputs["Result"], zw.inputs[0])
    links.new(zw.outputs[0], dsum.inputs[0])
    links.new(st.outputs["Result"], dsum.inputs[1])
    dirt = nodes.new("ShaderNodeMixRGB")
    dirt.blend_type = "MULTIPLY"
    links.new(dsum.outputs[0], dirt.inputs["Fac"])
    links.new(wear.outputs["Color"], dirt.inputs["Color1"])
    dirt.inputs["Color2"].default_value = (*look.get("dirt_col", (0.18, 0.15, 0.11)), 1)
    # muschio (o neve) sulle facce rivolte in su, a chiazze
    nz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], nz.inputs["Vector"])
    up = nodes.new("ShaderNodeMapRange")
    up.inputs["From Min"].default_value = 0.6
    up.inputs["From Max"].default_value = 0.95
    links.new(nz.outputs["Z"], up.inputs["Value"])
    mn = nodes.new("ShaderNodeTexNoise")
    mn.inputs["Scale"].default_value = 0.35
    mn.inputs["Detail"].default_value = 8
    mm = nodes.new("ShaderNodeMapRange")
    mm.inputs["From Min"].default_value = 0.5
    mm.inputs["From Max"].default_value = 0.62
    links.new(mn.outputs["Fac"], mm.inputs["Value"])
    mt = nodes.new("ShaderNodeMath")
    mt.operation = "MULTIPLY"
    links.new(up.outputs["Result"], mt.inputs[0])
    links.new(mm.outputs["Result"], mt.inputs[1])
    mt2 = nodes.new("ShaderNodeMath")
    mt2.operation = "MULTIPLY"
    mt2.inputs[1].default_value = look.get("moss", 0.6)
    links.new(mt.outputs[0], mt2.inputs[0])
    moss = nodes.new("ShaderNodeMixRGB")
    links.new(mt2.outputs[0], moss.inputs["Fac"])
    links.new(dirt.outputs["Color"], moss.inputs["Color1"])
    moss.inputs["Color2"].default_value = (*look.get("moss_col", (0.16, 0.22, 0.10)), 1)
    # rugosita': piu' liscia sugli spigoli consumati
    rr = nodes.new("ShaderNodeMath")
    rr.operation = "MULTIPLY_ADD"
    rr.inputs[1].default_value = -0.25
    rr.use_clamp = True
    sepr = nodes.new("ShaderNodeSeparateColor")
    links.new(rough.outputs["Color"], sepr.inputs["Color"])
    links.new(edgen.outputs[0], rr.inputs[0])
    links.new(sepr.outputs[0], rr.inputs[2])
    # normali
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.uv_map = "Tile"
    nmap.inputs["Strength"].default_value = look.get("normal", 1.0)
    links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    emit = nodes.new("ShaderNodeEmission")
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    target = nodes.new("ShaderNodeTexImage")
    target.name = "BAKE_TARGET"
    return m, {"color": moss.outputs["Color"], "rough": rr.outputs[0], "bsdf": bsdf, "emit": emit, "out": out, "target": target, "links": links}


def bake_piece(ob, base_mat, texdir, outdir, name, res=1024, look=None, samples=16):
    """cuoce il pezzo: scrive <name>_BaseColor.jpg, _Normal.png, _Roughness.png in outdir e mette al
    pezzo il materiale finale <name> (texture sulla UV 'Bake', unica UV rimasta)"""
    look = look or {}
    t0 = time.time()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = 6
    _uv_unique(ob)
    src, nd = _source_material(ob, base_mat, texdir, look)
    keep = list(ob.data.materials)
    ob.data.materials.clear()
    ob.data.materials.append(src)
    # solo questo pezzo nel render (la cottura e' uguale per tutte le copie)
    hidden = []
    for o in scene.objects:
        if o is not ob and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    imgs = {}
    for kind, noncolor in (("BaseColor", False), ("Roughness", True), ("Normal", True)):
        im = bpy.data.images.new("%s_%s" % (name, kind), res, res, alpha=False, float_buffer=False)
        if noncolor:
            im.colorspace_settings.name = "Non-Color"
        nd["target"].image = im
        nt = src.node_tree
        for n in nt.nodes:
            n.select = False
        nd["target"].select = True
        nt.nodes.active = nd["target"]
        links = nd["links"]
        for l in list(nd["out"].inputs["Surface"].links):
            links.remove(l)
        if kind == "Normal":
            links.new(nd["bsdf"].outputs["BSDF"], nd["out"].inputs["Surface"])
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", uv_layer="Bake", use_clear=True)
        else:
            src_out = nd["color"] if kind == "BaseColor" else nd["rough"]
            for l in list(nd["emit"].inputs["Color"].links):
                links.remove(l)
            links.new(src_out, nd["emit"].inputs["Color"])
            links.new(nd["emit"].outputs["Emission"], nd["out"].inputs["Surface"])
            bpy.ops.object.bake(type="EMIT", uv_layer="Bake", use_clear=True)
        os.makedirs(outdir, exist_ok=True)
        if kind == "BaseColor":
            path = os.path.join(outdir, "%s_%s.jpg" % (name, kind))
            im.filepath_raw = path
            im.file_format = "JPEG"
            scene.render.image_settings.quality = 90
            im.save(quality=90)
        else:
            path = os.path.join(outdir, "%s_%s.png" % (name, kind))
            im.filepath_raw = path
            im.file_format = "PNG"
            im.save()
            L.png_leggera(path, gray=(kind == "Roughness"), quant=2 if kind == "Normal" else 1)
        imgs[kind] = path
    for o in hidden:
        o.hide_render = False
    # materiale finale (anteprime ed export): texture cotte sulla UV "Bake"
    fin = bpy.data.materials.new(name)
    fin.use_nodes = True
    nt = fin.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "Bake"
    for kind, sock in (("BaseColor", "Base Color"), ("Roughness", "Roughness"), ("Normal", None)):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(imgs[kind], check_existing=True)
        nt.links.new(uv.outputs["UV"], t.inputs["Vector"])
        if kind != "BaseColor":
            t.image.colorspace_settings.name = "Non-Color"
        if sock:
            nt.links.new(t.outputs["Color"], bsdf.inputs[sock])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.uv_map = "Bake"
            nt.links.new(t.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    ob.data.materials.clear()
    ob.data.materials.append(fin)
    _drop_tile(ob)
    print("  cotto %s (%.0fs)" % (name, time.time() - t0), flush=True)
    return fin, imgs


def _drop_tile(ob):
    me = ob.data
    t = me.uv_layers.get("Tile")
    if t:
        me.uv_layers.remove(t)
    if me.uv_layers.get("Bake"):
        me.uv_layers.active = me.uv_layers["Bake"]


def share_bake(src_ob, dst_ob):
    """dst ha la stessa geometria di src (stesso ordine): copia la UV cotta e il materiale"""
    sme, dme = src_ob.data, dst_ob.data
    if len(sme.loops) != len(dme.loops):
        raise ValueError("geometria diversa: %s / %s" % (src_ob.name, dst_ob.name))
    uv = dme.uv_layers.get("Bake") or dme.uv_layers.new(name="Bake")
    buf = [0.0] * (len(sme.loops) * 2)
    sme.uv_layers["Bake"].data.foreach_get("uv", buf)
    uv.data.foreach_set("uv", buf)
    dme.uv_layers.active = uv
    _drop_tile(dst_ob)
    dme.materials.clear()
    dme.materials.append(sme.materials[0])
