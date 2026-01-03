<script lang="ts">
	import { onMount } from 'svelte';

	let canvas: HTMLCanvasElement;
	let width: number;
	let height: number;
	let cubes: RainbowCube3D[] = [];
	let mouse = { x: undefined as number | undefined, y: undefined as number | undefined };

	class POINT3D {
		x: number;
		y: number;
		z: number;
		constructor(x: number, y: number, z: number) {
			this.x = x;
			this.y = y;
			this.z = z;
		}
	}

	class RainbowCube3D {
		size: number;
		x: number;
		y: number;
		z: number;
		vx: number;
		vy: number;
		rx: number;
		ry: number;
		vrx: number;
		vry: number;
		hueOffset: number;
		vertices: POINT3D[];
		faces: number[][];

		constructor() {
			this.vertices = [
				new POINT3D(-1, -1, -1),
				new POINT3D(1, -1, -1),
				new POINT3D(1, 1, -1),
				new POINT3D(-1, 1, -1),
				new POINT3D(-1, -1, 1),
				new POINT3D(1, -1, 1),
				new POINT3D(1, 1, 1),
				new POINT3D(-1, 1, 1)
			];

			this.faces = [
				[0, 1, 2, 3],
				[1, 5, 6, 2],
				[5, 4, 7, 6],
				[4, 0, 3, 7],
				[3, 2, 6, 7],
				[4, 5, 1, 0]
			];

			this.size = Math.random() * 50 + 30;
			this.x = Math.random() * width;
			this.y = Math.random() * height;
			this.z = Math.random() * 0.5 + 0.5;
			this.vx = (Math.random() - 0.5) * 0.5;
			this.vy = (Math.random() - 0.5) * 0.5;
			this.rx = Math.random() * Math.PI * 2;
			this.ry = Math.random() * Math.PI * 2;
			this.vrx = (Math.random() - 0.5) * 0.015;
			this.vry = (Math.random() - 0.5) * 0.015;
			this.hueOffset = Math.random() * 360;
		}

		project(x: number, y: number, z: number) {
			return {
				x: this.x + x * this.size,
				y: this.y + y * this.size
			};
		}

		update() {
			this.x += this.vx * this.z;
			this.y += this.vy * this.z;
			this.rx += this.vrx;
			this.ry += this.vry;

			if (mouse.x !== undefined && mouse.y !== undefined) {
				const dx = this.x - mouse.x;
				const dy = this.y - mouse.y;
				const dist = Math.sqrt(dx * dx + dy * dy);
				const radius = 300;

				if (dist < radius) {
					const force = (radius - dist) / radius;
					this.x += (dx / dist) * force * 2;
					this.y += (dy / dist) * force * 2;
					this.rx += this.vrx * 2;
					this.ry += this.vry * 2;
				}
			}

			const margin = 150;
			if (this.x < -margin) this.x = width + margin;
			if (this.x > width + margin) this.x = -margin;
			if (this.y < -margin) this.y = height + margin;
			if (this.y > height + margin) this.y = -margin;
		}

		draw(ctx: CanvasRenderingContext2D) {
			let transformedVertices = this.vertices.map((v) => {
				let x1 = v.x * Math.cos(this.ry) - v.z * Math.sin(this.ry);
				let z1 = v.x * Math.sin(this.ry) + v.z * Math.cos(this.ry);
				let y1 = v.y * Math.cos(this.rx) - z1 * Math.sin(this.rx);
				let z2 = v.y * Math.sin(this.rx) + z1 * Math.cos(this.rx);
				return { x: x1, y: y1, z: z2 };
			});

			let projectedPoints = transformedVertices.map((v) => this.project(v.x, v.y, v.z));

			const lightDir = { x: 0.5, y: -0.8, z: -1 };
			const len = Math.sqrt(lightDir.x ** 2 + lightDir.y ** 2 + lightDir.z ** 2);
			lightDir.x /= len;
			lightDir.y /= len;
			lightDir.z /= len;

			ctx.lineJoin = 'round';
			ctx.lineCap = 'round';

			this.faces.forEach((face) => {
				const v0 = transformedVertices[face[0]];
				const v1 = transformedVertices[face[1]];
				const v2 = transformedVertices[face[2]];

				const A = { x: v1.x - v0.x, y: v1.y - v0.y, z: v1.z - v0.z };
				const B = { x: v2.x - v0.x, y: v2.y - v0.y, z: v2.z - v0.z };

				const nx = A.y * B.z - A.z * B.y;
				const ny = A.z * B.x - A.x * B.z;
				const nz = A.x * B.y - A.y * B.x;

				const nLen = Math.sqrt(nx * nx + ny * ny + nz * nz);
				const normal = { x: nx / nLen, y: ny / nLen, z: nz / nLen };

				let intensity = normal.x * lightDir.x + normal.y * lightDir.y + normal.z * lightDir.z;
				let brightness = Math.max(0.2, intensity);

				const alpha = 0.6 + brightness * 0.3;
				const lightness = 75 + brightness * 15;

				const p = face.map((idx) => projectedPoints[idx]);

				const grad = ctx.createLinearGradient(p[0].x, p[0].y, p[2].x, p[2].y);
				grad.addColorStop(0.0, `hsla(340, 100%, ${lightness}%, ${alpha})`);
				grad.addColorStop(0.3, `hsla(40,  100%, ${lightness}%, ${alpha})`);
				grad.addColorStop(0.6, `hsla(200, 100%, ${lightness}%, ${alpha})`);
				grad.addColorStop(1.0, `hsla(260, 100%, ${lightness}%, ${alpha})`);

				ctx.beginPath();
				ctx.moveTo(p[0].x, p[0].y);
				ctx.lineTo(p[1].x, p[1].y);
				ctx.lineTo(p[2].x, p[2].y);
				ctx.lineTo(p[3].x, p[3].y);
				ctx.closePath();

				ctx.fillStyle = grad;
				ctx.strokeStyle = grad;
				ctx.lineWidth = 32;

				ctx.stroke();
				ctx.fill();

				if (intensity > 0.5) {
					const glossOpacity = (intensity - 0.5) * 0.9;
					const glossGrad = ctx.createLinearGradient(p[0].x, p[0].y, p[2].x, p[2].y);
					glossGrad.addColorStop(0, `rgba(255, 255, 255, ${glossOpacity})`);
					glossGrad.addColorStop(0.6, `rgba(255, 255, 255, 0)`);

					ctx.fillStyle = glossGrad;
					ctx.fill();
				}
			});
		}
	}

	function initCubes() {
		cubes = [];
		const numCubes = Math.floor((width * height) / 100000);
		for (let i = 0; i < numCubes; i++) {
			cubes.push(new RainbowCube3D());
		}
	}

	function resize() {
		const dpr = Math.max(window.devicePixelRatio || 1, 2);
		width = window.innerWidth;
		height = window.innerHeight;
		canvas.width = width * dpr;
		canvas.height = height * dpr;
		const ctx = canvas.getContext('2d');
		if (ctx) {
			ctx.scale(dpr, dpr);
		}
		initCubes();
	}

	function animate() {
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		ctx.clearRect(0, 0, width, height);

		for (let i = 0; i < cubes.length; i++) {
			cubes[i].update();
			cubes[i].draw(ctx);
		}

		requestAnimationFrame(animate);
	}

	onMount(() => {
		resize();
		animate();

		const handleResize = () => resize();
		const handleMouseMove = (e: MouseEvent) => {
			mouse.x = e.x;
			mouse.y = e.y;
		};
		const handleMouseLeave = () => {
			mouse.x = undefined;
			mouse.y = undefined;
		};

		window.addEventListener('resize', handleResize);
		window.addEventListener('mousemove', handleMouseMove);
		window.addEventListener('mouseleave', handleMouseLeave);

		return () => {
			window.removeEventListener('resize', handleResize);
			window.removeEventListener('mousemove', handleMouseMove);
			window.removeEventListener('mouseleave', handleMouseLeave);
		};
	});
</script>

<canvas id="bgCanvas" bind:this={canvas}></canvas>

<div class="container">
	<div class="badge">
		<span class="badge-dot"></span>
		LIVE
	</div>
	<h1>Tory's Server</h1>
	<p>Welcome to Tory Space!</p>
	<footer>&copy; 2025 Tory's Server. All Rights Reserved.</footer>
</div>

<style>
	@import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.css');

	:global(body) {
		margin: 0;
		padding: 0;
		box-sizing: border-box;
		font-family:
			'Pretendard',
			-apple-system,
			BlinkMacSystemFont,
			system-ui,
			Roboto,
			sans-serif;
		background-color: #fdfbf7;
		color: #2d3436;
		height: 100vh;
		overflow: hidden;
	}

	#bgCanvas {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		z-index: 0;
	}

	.container {
		position: fixed;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		z-index: 10;
		background: rgba(255, 255, 255, 0.65);
		backdrop-filter: blur(40px) saturate(180%);
		-webkit-backdrop-filter: blur(40px) saturate(180%);
		padding: 4.5rem 4rem;
		border-radius: 48px;
		border: 2px solid #ffffff;
		text-align: center;
		max-width: 680px;
		width: 90%;
		box-shadow:
			0 20px 40px rgba(0, 0, 0, 0.05),
			0 0 0 1px rgba(255, 255, 255, 0.5) inset;
		transition:
			transform 0.3s ease,
			box-shadow 0.3s ease;
	}

	.container:hover {
		transform: translate(-50%, -50%) translateY(-5px);
		box-shadow:
			0 30px 60px rgba(0, 0, 0, 0.08),
			0 0 0 1px rgba(255, 255, 255, 0.6) inset;
	}

	.badge {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 10px 24px;
		background: #ffffff;
		border-radius: 100px;
		font-size: 0.9rem;
		font-weight: 700;
		color: #2d3436;
		margin-bottom: 2rem;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06);
		border: 1px solid rgba(0, 0, 0, 0.05);
	}

	.badge-dot {
		width: 10px;
		height: 10px;
		background-color: #00cec9;
		border-radius: 50%;
		box-shadow: 0 0 0 3px rgba(0, 206, 201, 0.2);
		animation: pulse 2s infinite;
	}

	h1 {
		font-size: 4.5rem;
		font-weight: 900;
		margin-bottom: 1rem;
		letter-spacing: -0.04em;
		background: linear-gradient(135deg, #6c5ce7 0%, #fd79a8 100%);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	p {
		font-size: 1.35rem;
		line-height: 1.6;
		color: #636e72;
		margin-bottom: 3rem;
		font-weight: 500;
	}

	footer {
		font-size: 0.9rem;
		color: #b2bec3;
		font-weight: 600;
	}

	@keyframes pulse {
		0% {
			transform: scale(0.95);
			box-shadow: 0 0 0 0 rgba(0, 206, 201, 0.4);
		}
		70% {
			transform: scale(1);
			box-shadow: 0 0 0 8px rgba(0, 206, 201, 0);
		}
		100% {
			transform: scale(0.95);
			box-shadow: 0 0 0 0 rgba(0, 206, 201, 0);
		}
	}

	@media (max-width: 768px) {
		h1 {
			font-size: 3rem;
		}
		.container {
			padding: 3rem 2rem;
		}
	}
</style>
