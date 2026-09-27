// Builds drop-in character GLBs from Quaternius CC0 modular characters:
// an outfit body + head + hairstyles, the Universal Animation Library
// clips renamed to the clip names the game already uses (KayKit names),
// and "handslot.r"/"handslot.l" grip joints so weapons attach as before.
//
//   cd tools/build_humans && npm install && node build_humans.mjs
//
// Output: art/third_party/quaternius/humans/<name>.glb
import { NodeIO } from '@gltf-transform/core';
import { mergeDocuments, prune, dedup } from '@gltf-transform/functions';
import fs from 'node:fs';
import path from 'node:path';

const SRC = 'src';
const OUT = '../../art/third_party/quaternius/humans';
const io = new NodeIO();

// Game clip name -> [library file, source clip, loop].
const CLIPS = {
	Idle: ['UAL1', 'Idle_Loop', true],
	Unarmed_Idle: ['UAL1', 'Idle_Loop', true],
	Idle_Combat: ['UAL1', 'Sword_Idle', true],
	'2H_Melee_Idle': ['UAL1', 'Sword_Idle', true],
	Walking_A: ['UAL1', 'Walk_Loop', true],
	Walking_Backwards: ['UAL1', 'Walk_Loop', true],
	Running_A: ['UAL1', 'Jog_Fwd_Loop', true],
	Running_B: ['UAL1', 'Sprint_Loop', true],
	Running_Strafe_Left: ['UAL1', 'Jog_Fwd_Loop', true],
	Running_Strafe_Right: ['UAL1', 'Jog_Fwd_Loop', true],
	Jump_Idle: ['UAL1', 'Jump_Loop', true],
	Jump_Start: ['UAL1', 'Jump_Start', false],
	Jump_Land: ['UAL1', 'Jump_Land', false],
	Hit_A: ['UAL1', 'Hit_Chest', false],
	Hit_B: ['UAL1', 'Hit_Head', false],
	Death_A: ['UAL1', 'Death01', false],
	Dodge_Forward: ['UAL1', 'Roll', false, { len: 0.6 }],
	Interact: ['UAL1', 'Interact', false, { len: 1.3 }],
	PickUp: ['UAL1', 'PickUp_Table', false, { len: 1.3 }],
	Throw: ['UAL2', 'OverhandThrow', false],
	Blocking: ['UAL2', 'Sword_Block', true],
	Block: ['UAL2', 'Sword_Block', true],
	Block_Hit: ['UAL2', 'Idle_Shield_Break', false],
	Block_Attack: ['UAL1', 'Punch_Cross', false, { len: 1.07, peak: 0.56, srcPeak: 0.2 }],
	'1H_Melee_Attack_Chop': ['UAL2', ['Sword_Regular_A', 'Sword_Regular_A_Rec'], false, { len: 1.07, peak: 0.63, srcPeak: 0.25 }],
	'1H_Melee_Attack_Slice_Diagonal': ['UAL2', ['Sword_Regular_B', 'Sword_Regular_B_Rec'], false, { len: 1.0, peak: 0.45, srcPeak: 0.27 }],
	'1H_Melee_Attack_Slice_Horizontal': ['UAL2', 'Sword_Regular_C', false, { trim: [0, 1.45], len: 1.07, peak: 0.25, srcPeak: 0.67 }],
	'2H_Melee_Attack_Chop': ['UAL1', 'Sword_Attack', false, { len: 1.63, peak: 0.85, srcPeak: 0.41 }],
	'1H_Ranged_Shoot': ['UAL1', 'Pistol_Shoot', false, { len: 1.07 }],
	'2H_Ranged_Shoot': ['UAL1', 'Pistol_Shoot', false, { len: 1.07 }],
	'2H_Ranged_Aiming': ['UAL1', 'Pistol_Aim_Neutral', true],
	Spellcast_Shoot: ['UAL1', 'Spell_Simple_Shoot', false, { len: 0.93 }],
	Spellcast_Raise: ['UAL1', ['Spell_Simple_Enter', 'Spell_Simple_Shoot'], false, { len: 2.1 }],
	Spellcast_Long: ['UAL1', ['Spell_Simple_Enter', 'Spell_Simple_Idle_Loop', 'Spell_Simple_Shoot'], false, { len: 2.53 }],
	Spellcast_Summon: ['UAL1', ['Spell_Simple_Enter', 'Spell_Simple_Idle_Loop', 'Spell_Simple_Shoot'], false, { len: 2.9 }],
	Chop: ['UAL2', 'TreeChopping_Loop', true],
	Chopping: ['UAL2', 'TreeChopping_Loop', true],
	Farm_Harvest: ['UAL2', 'Farm_Harvest', false],
	Farm_PlantSeed: ['UAL2', 'Farm_PlantSeed', false],
	Carry_Walk: ['UAL2', 'Walk_Carry_Loop', true],
	Talking: ['UAL1', 'Idle_Talking_Loop', true],
	Sit_Idle: ['UAL1', 'Sitting_Idle_Loop', true],
	Fold_Arms: ['UAL2', 'Idle_FoldArms_Loop', true],
	Cheer: ['UAL2', 'Yes', false],
	Zombie_Idle: ['UAL2', 'Zombie_Idle_Loop', true],
	Zombie_Walk: ['UAL2', 'Zombie_Walk_Fwd_Loop', true],
	Zombie_Scratch: ['UAL2', 'Zombie_Scratch', false],
	// Undead spawns and the necromancer's casts.
	Skeletons_Awaken_Floor: ['UAL2', 'LayToIdle', false],
	Skeletons_Awaken_Standing: ['UAL2', 'Idle_Shield_Break', false],
	Spawn_Ground_Skeletons: ['UAL2', 'LayToIdle', false],
};

// Character recipes: outfit + head + hair pieces.
const PEOPLE = {
	fighter: { outfit: 'characters/Male_Knight_Cloth', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_Buzzed', 'hair/Hair_Beard'], hairColor: [0.05, 0.03, 0.015, 1], drop: ['Head_Horns'], prefix: 'Male_Knight_' },
	ranger: { outfit: 'characters/Female_Ranger', head: 'heads/Regular_Female_OnlyHead', hair: ['hair/Hair_Long'], hairColor: [0.2, 0.07, 0.02, 1] },
	wizard: { outfit: 'characters/Male_Wizard', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_Long', 'hair/Hair_Beard'], hairColor: [0.55, 0.55, 0.55, 1] },
	peasant_m: { outfit: 'characters/Male_Peasant', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_SlickBack', 'hair/Hair_Moustache'], hairColor: [0.03, 0.02, 0.012, 1] },
	peasant_m2: { outfit: 'characters/Male_Peasant', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_Balding', 'hair/Hair_Beard'], hairColor: [0.12, 0.08, 0.05, 1] },
	peasant_f: { outfit: 'characters/Female_Peasant', head: 'heads/Regular_Female_OnlyHead', hair: ['hair/Hair_Bob'], hairColor: [0.09, 0.045, 0.02, 1] },
	// The shared animation library (a peasant body carries the clips).
	human_anims: { outfit: 'characters/Male_Peasant', head: 'heads/Regular_Male_OnlyHead', hair: [], anims: true },
	// The risen dead: grave-grey skin, glowing eyes, no hair.
	undead_warrior: { outfit: 'characters/Male_Knight_Cloth', head: 'heads/Regular_Male_OnlyHead', hair: [], prefix: 'Male_Knight_', drop: ['Head_Horns'], undead: true },
	undead_archer: { outfit: 'characters/Female_Ranger', head: 'heads/Regular_Female_OnlyHead', hair: [], undead: true },
	undead_minion: { outfit: 'characters/Male_Peasant', head: 'heads/Regular_Male_OnlyHead', hair: [], undead: true },
	undead_champion: { outfit: 'characters/Male_Knight_Cloth', head: 'heads/Regular_Male_OnlyHead', hair: [], prefix: 'Male_Knight_', undead: true },
	necromancer: { outfit: 'characters/Male_Wizard', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_Long'], hairColor: [0.6, 0.6, 0.58, 1], undead: true },
	noble_m: { outfit: 'characters/Male_Noble', head: 'heads/Regular_Male_OnlyHead', hair: ['hair/Hair_SlickBack', 'hair/Hair_Moustache'], hairColor: [0.25, 0.22, 0.2, 1], drop: ['Head_Crown', 'Acc_Pauldron_Lion', 'Acc_Pauldron'] },
};

// Grip joints ("handslot.r"/"handslot.l"), defined in world space at the
// bind (T) pose and converted to hand-local transforms. Convention for held
// items: the grip is at the origin and the item's +Y runs up the handle
// (blade, haft, staff); a shield's face looks along +Z.
// At the T-pose the arms run along ±X, palms face down, the body faces +Z.
const GRIPS = {
	// Blade forward along the thumb (+Z), flat of the blade vertical.
	'handslot.r': { parent: 'hand_r', offset: [-0.075, -0.025, 0.01], x: [-1, 0, 0], y: [0, 0, 1] },
	// Shield face along the forearm (+X, outward at the T-pose), top forward.
	'handslot.l': { parent: 'hand_l', offset: [0.06, 0.0, 0.0], x: [0, 1, 0], y: [0, 0, 1] },
};

function cross(a, b) { return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]; }
function norm(a) { const l = Math.hypot(...a); return a.map((v) => v / l); }
// Rotation matrix (columns x, y, z) -> quaternion [x, y, z, w].
function matToQuat(x, y, z) {
	const m00 = x[0], m10 = x[1], m20 = x[2], m01 = y[0], m11 = y[1], m21 = y[2], m02 = z[0], m12 = z[1], m22 = z[2];
	const tr = m00 + m11 + m22;
	let q;
	if (tr > 0) { const s = Math.sqrt(tr + 1) * 2; q = [(m21 - m12) / s, (m02 - m20) / s, (m10 - m01) / s, 0.25 * s]; }
	else if (m00 > m11 && m00 > m22) { const s = Math.sqrt(1 + m00 - m11 - m22) * 2; q = [0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s]; }
	else if (m11 > m22) { const s = Math.sqrt(1 + m11 - m00 - m22) * 2; q = [(m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s]; }
	else { const s = Math.sqrt(1 + m22 - m00 - m11) * 2; q = [(m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s]; }
	return q;
}
// Local transform (relative to `parent`) for a world-space frame at the bind pose.
function localGrip(parent, g) {
	const P = parent.getWorldMatrix();  // column-major
	const col = (i) => [P[i * 4], P[i * 4 + 1], P[i * 4 + 2]];
	const sx = Math.hypot(...col(0)), sy = Math.hypot(...col(1)), sz = Math.hypot(...col(2));
	const R = [col(0).map((v) => v / sx), col(1).map((v) => v / sy), col(2).map((v) => v / sz)];  // world axes of parent
	const dot = (a, b) => a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
	const x = norm(g.x), y = norm(g.y), z = cross(x, y);
	// Express the desired world axes in the parent's frame (R is orthonormal).
	const toLocal = (v) => [dot(v, R[0]), dot(v, R[1]), dot(v, R[2])];
	const t = toLocal(g.offset).map((v, i) => v / [sx, sy, sz][i]);
	return { t, r: matToQuat(toLocal(x), toLocal(y), toLocal(z)) };
}

function byName(doc) {
	const m = new Map();
	for (const n of doc.getRoot().listNodes()) m.set(n.getName(), n);
	return m;
}

function invert4(m) {
	// Column-major 4x4 inverse (general).
	const inv = new Array(16);
	inv[0] = m[5]*m[10]*m[15]-m[5]*m[11]*m[14]-m[9]*m[6]*m[15]+m[9]*m[7]*m[14]+m[13]*m[6]*m[11]-m[13]*m[7]*m[10];
	inv[4] = -m[4]*m[10]*m[15]+m[4]*m[11]*m[14]+m[8]*m[6]*m[15]-m[8]*m[7]*m[14]-m[12]*m[6]*m[11]+m[12]*m[7]*m[10];
	inv[8] = m[4]*m[9]*m[15]-m[4]*m[11]*m[13]-m[8]*m[5]*m[15]+m[8]*m[7]*m[13]+m[12]*m[5]*m[11]-m[12]*m[7]*m[9];
	inv[12] = -m[4]*m[9]*m[14]+m[4]*m[10]*m[13]+m[8]*m[5]*m[14]-m[8]*m[6]*m[13]-m[12]*m[5]*m[10]+m[12]*m[6]*m[9];
	inv[1] = -m[1]*m[10]*m[15]+m[1]*m[11]*m[14]+m[9]*m[2]*m[15]-m[9]*m[3]*m[14]-m[13]*m[2]*m[11]+m[13]*m[3]*m[10];
	inv[5] = m[0]*m[10]*m[15]-m[0]*m[11]*m[14]-m[8]*m[2]*m[15]+m[8]*m[3]*m[14]+m[12]*m[2]*m[11]-m[12]*m[3]*m[10];
	inv[9] = -m[0]*m[9]*m[15]+m[0]*m[11]*m[13]+m[8]*m[1]*m[15]-m[8]*m[3]*m[13]-m[12]*m[1]*m[11]+m[12]*m[3]*m[9];
	inv[13] = m[0]*m[9]*m[14]-m[0]*m[10]*m[13]-m[8]*m[1]*m[14]+m[8]*m[2]*m[13]+m[12]*m[1]*m[10]-m[12]*m[2]*m[9];
	inv[2] = m[1]*m[6]*m[15]-m[1]*m[7]*m[14]-m[5]*m[2]*m[15]+m[5]*m[3]*m[14]+m[13]*m[2]*m[7]-m[13]*m[3]*m[6];
	inv[6] = -m[0]*m[6]*m[15]+m[0]*m[7]*m[14]+m[4]*m[2]*m[15]-m[4]*m[3]*m[14]-m[12]*m[2]*m[7]+m[12]*m[3]*m[6];
	inv[10] = m[0]*m[5]*m[15]-m[0]*m[7]*m[13]-m[4]*m[1]*m[15]+m[4]*m[3]*m[13]+m[12]*m[1]*m[7]-m[12]*m[3]*m[5];
	inv[14] = -m[0]*m[5]*m[14]+m[0]*m[6]*m[13]+m[4]*m[1]*m[14]-m[4]*m[2]*m[13]-m[12]*m[1]*m[6]+m[12]*m[2]*m[5];
	inv[3] = -m[1]*m[6]*m[11]+m[1]*m[7]*m[10]+m[5]*m[2]*m[11]-m[5]*m[3]*m[10]-m[9]*m[2]*m[7]+m[9]*m[3]*m[6];
	inv[7] = m[0]*m[6]*m[11]-m[0]*m[7]*m[10]-m[4]*m[2]*m[11]+m[4]*m[3]*m[10]+m[8]*m[2]*m[7]-m[8]*m[3]*m[6];
	inv[11] = -m[0]*m[5]*m[11]+m[0]*m[7]*m[9]+m[4]*m[1]*m[11]-m[4]*m[3]*m[9]-m[8]*m[1]*m[7]+m[8]*m[3]*m[5];
	inv[15] = m[0]*m[5]*m[10]-m[0]*m[6]*m[9]-m[4]*m[1]*m[10]+m[4]*m[2]*m[9]+m[8]*m[1]*m[6]-m[8]*m[2]*m[5];
	const det = m[0]*inv[0]+m[1]*inv[4]+m[2]*inv[8]+m[3]*inv[12];
	return inv.map((v) => v / det);
}

async function build(name, recipe, libs) {
	const doc = await io.read(path.join(SRC, recipe.outfit + '.gltf'));
	const root = doc.getRoot();
	const baseScene = root.listScenes()[0];
	const base = byName(doc);
	const skin = root.listSkins()[0];
	const armature = base.get('Armature');
	const baseJoints = new Set(skin.listJoints());
	// Some outfit files carry sibling outfits and optional accessories:
	// keep only this outfit's meshes, minus the pieces the recipe drops.
	const prefix = recipe.prefix || path.basename(recipe.outfit) + '_';
	for (const n of root.listNodes()) {
		if (!n.getMesh()) continue;
		const nm = n.getName();
		if (!nm.startsWith(prefix) || (recipe.drop || []).some((d) => nm.endsWith(d))) n.dispose();
	}

	// Head and hair: merge, rebind their skinned meshes to our joints.
	for (const part of [recipe.head, ...recipe.hair]) {
		const other = await io.read(path.join(SRC, part + '.gltf'));
		const before = new Set(root.listNodes());
		mergeDocuments(doc, other);
		const added = root.listNodes().filter((n) => !before.has(n));
		const rebound = new Map();  // part skin -> our skin
		const keep = new Set();
		for (const n of added) {
			const partSkin = n.getSkin();
			if (!(n.getMesh() && partSkin)) continue;
			if (!rebound.has(partSkin)) {
				// Same joint names: rebuild the skin against our joints.
				const ibmSrc = partSkin.getInverseBindMatrices();
				const ibmCopy = doc.createAccessor().setType(ibmSrc.getType()).setArray(ibmSrc.getArray().slice());
				const newSkin = doc.createSkin(n.getName() + '_skin')
					.setInverseBindMatrices(ibmCopy)
					.setSkeleton(base.get('root'));
				for (const j of partSkin.listJoints()) newSkin.addJoint(base.get(j.getName()));
				rebound.set(partSkin, newSkin);
			}
			n.setSkin(rebound.get(partSkin));
			armature.addChild(n);
			keep.add(n);
			// Hair colour: the kit's hair texture is grey, tinted per character.
			for (const prim of n.getMesh().listPrimitives()) {
				const mat = prim.getMaterial();
				if (mat && mat.getName().startsWith('MI_Hair') && recipe.hairColor) {
					const tinted = mat.clone().setName(mat.getName() + '_' + name).setBaseColorFactor(recipe.hairColor)
						.setRoughnessFactor(0.85).setMetallicFactor(0);
					prim.setMaterial(tinted);
				}
			}
		}
		for (const s of rebound.keys()) s.dispose();
		// Drop the part's own scenes and leftover skeleton nodes.
		for (const s of root.listScenes()) if (s !== baseScene) s.dispose();
		for (const n of added) if (!keep.has(n)) n.dispose();
	}

	// Grip joints.
	for (const [gname, g] of Object.entries(GRIPS)) {
		const parent = base.get(g.parent);
		const lg = localGrip(parent, g);
		const node = doc.createNode(gname).setTranslation(lg.t).setRotation(lg.r);
		parent.addChild(node);
		// Add to every skin so Godot creates the bone with a bind pose.
		for (const s of root.listSkins()) {
			const ibm = s.getInverseBindMatrices();
			if (!ibm || s.listJoints().length !== ibm.getCount()) continue;
			const inv = invert4(node.getWorldMatrix());
			const copy = doc.createAccessor().setType('MAT4').setArray(new Float32Array([...Array.from(ibm.getArray()), ...inv]));
			s.setInverseBindMatrices(copy);
			s.addJoint(node);
		}
	}

	// The risen dead: tint skin and clothes, light the eyes.
	if (recipe.undead) {
		for (const mat of root.listMaterials()) {
			const n = mat.getName();
			if (/Regular_(Male|Female)/.test(n)) {
				// Grave-pale, bloodless skin.
				mat.setBaseColorFactor([0.62, 0.64, 0.52, 1]);
			} else if (/Eye/.test(n)) {
				mat.setEmissiveFactor([1.0, 0.25, 0.1]).setBaseColorFactor([0.2, 0.05, 0.02, 1]);
				if (mat.getBaseColorTexture()) mat.setEmissiveTexture(null);
			} else if (!/Hair/.test(n)) {
				// Grave-rotted clothes: dark, mouldy green-grey.
				mat.setBaseColorFactor([0.3, 0.32, 0.27, 1]);
			}
		}
	}
	// Animations: copy each wanted clip, retargeted to our nodes by name.
	// Only the shared library file carries them; bodies load it at runtime.
	for (const [clipName, [lib, srcSpec, loop, warp]] of Object.entries(recipe.anims ? CLIPS : {})) {
		const libDoc = libs[lib];
		const sources = Array.isArray(srcSpec) ? srcSpec : [srcSpec];
		const anims = sources.map((n) => libDoc.getRoot().listAnimations().find((a) => a.getName() === n));
		if (anims.some((a) => !a)) { console.warn('missing clip', sources); continue; }
		// Concatenate the sources per (target, path), then trim and time-warp
		// so the strike lands where the game's attack windows expect it.
		const tracks = new Map();  // key -> {target, path, interp, times[], values[], size}
		let offset = 0;
		for (const anim of anims) {
			let len = 0;
			for (const ch of anim.listChannels()) {
				const target = base.get(ch.getTargetNode().getName());
				if (!target || !baseJoints.has(target)) continue;
				const sm = ch.getSampler();
				const times = sm.getInput().getArray();
				const vals = sm.getOutput().getArray();
				const size = sm.getOutput().getElementSize();
				len = Math.max(len, times[times.length - 1]);
				const key = target.getName() + '|' + ch.getTargetPath();
				if (!tracks.has(key)) tracks.set(key, { target, path: ch.getTargetPath(), interp: sm.getInterpolation(), times: [], values: [], size });
				const tr = tracks.get(key);
				for (let i = 0; i < times.length; i++) {
					tr.times.push(times[i] + offset);
					for (let k = 0; k < size; k++) tr.values.push(vals[i * size + k]);
				}
			}
			offset += len + 1 / 30;
		}
		const srcLen = offset - 1 / 30;
		const [t0, t1] = warp?.trim ?? [0, srcLen];
		const map = (t) => {
			let u = Math.min(Math.max(t, t0), t1) - t0;
			const L = t1 - t0;
			if (!warp?.len) return u;
			if (warp.peak === undefined) return u * warp.len / L;
			return u <= warp.srcPeak ? u * warp.peak / warp.srcPeak
				: warp.peak + (u - warp.srcPeak) * (warp.len - warp.peak) / (L - warp.srcPeak);
		};
		const out = doc.createAnimation(loop ? clipName + '-loop' : clipName);
		for (const tr of tracks.values()) {
			const times = [];
			const values = [];
			for (let i = 0; i < tr.times.length; i++) {
				const t = tr.times[i];
				// Keep keys inside the trim, plus the boundary keys either side.
				const prevIn = i > 0 && tr.times[i - 1] >= t0;
				const nextIn = i + 1 < tr.times.length && tr.times[i + 1] <= t1;
				if (t < t0 && !nextIn) continue;
				if (t > t1 && !prevIn) continue;
				const mt = map(t);
				if (times.length && mt <= times[times.length - 1]) continue;
				times.push(mt);
				for (let k = 0; k < tr.size; k++) values.push(tr.values[i * tr.size + k]);
			}
			if (!times.length) continue;
			const type = tr.size === 4 ? 'VEC4' : 'VEC3';
			const input = doc.createAccessor().setType('SCALAR').setArray(new Float32Array(times));
			const output = doc.createAccessor().setType(type).setArray(new Float32Array(values));
			const sampler = doc.createAnimationSampler().setInput(input).setOutput(output).setInterpolation(tr.interp === 'CUBICSPLINE' ? 'LINEAR' : tr.interp);
			out.addSampler(sampler);
			out.addChannel(doc.createAnimationChannel().setTargetNode(tr.target).setTargetPath(tr.path).setSampler(sampler));
		}
	}
	// One buffer for the GLB.
	const buffer = root.listBuffers()[0];
	for (const a of root.listAccessors()) a.setBuffer(buffer);
	for (const b of root.listBuffers()) if (b !== buffer) b.dispose();
	await doc.transform(prune({ keepLeaves: true }));
	for (const s of root.listSkins()) if (s.listJoints().length !== s.getInverseBindMatrices().getCount()) console.warn('skin mismatch', s.getName());
	fs.mkdirSync(OUT, { recursive: true });
	await io.write(path.join(OUT, name + '.glb'), doc);
	console.log('built', name, root.listAnimations().length, 'clips,', root.listMeshes().length, 'meshes');
}

const libs = {
	UAL1: await io.read(path.join(SRC, 'animations/UAL1.glb')),
	UAL2: await io.read(path.join(SRC, 'animations/UAL2.glb')),
};
const only = process.argv.slice(2);
for (const [name, recipe] of Object.entries(PEOPLE)) {
	if (only.length && !only.includes(name)) continue;
	await build(name, recipe, libs);
}
