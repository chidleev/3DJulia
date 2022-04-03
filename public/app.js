import * as THREE from './build/three.module.js'
import { OrbitControls } from './jsm/controls/OrbitControls.js'
import { EffectComposer } from './jsm/postprocessing/EffectComposer.js'
import { RenderPass } from './jsm/postprocessing/RenderPass.js'
import { ShaderPass } from './jsm/postprocessing/ShaderPass.js'

document.addEventListener('DOMContentLoaded', init())

function init() {
    THREE.Cache.enabled = true
    const shadersLoader = new THREE.FileLoader()
    shadersLoader.setResponseType("text")
    shadersLoader.load(
        'shaders/VS.glsl',
    
        // onLoad callback
        function ( data ) {
            THREE.Cache.add("VS", data)
            loadFragmentShader()
        },
    
        // onProgress callback
        function ( xhr ) {},
    
        // onError callback
        function ( err ) {
            console.error( err )
        }
    )

    function loadFragmentShader()
    {
        shadersLoader.load(
            'shaders/FS.glsl',
        
            // onLoad callback
            function ( data ) {
                THREE.Cache.add("FS", data)
                animationInit()
            },
        
            // onProgress callback
            function ( xhr ) {},
        
            // onError callback
            function ( err ) {
                console.error( err )
            }
        )
    }


    let renderer, composer, scene, camera, controls
    let VS = "", FS = ""
    let camDirection = new THREE.Vector3()
    const pixelRatio = 1
    
    function animationInit()
    {
        VS = THREE.Cache.get("VS")
        FS = THREE.Cache.get("FS")

        scene = new THREE.Scene()
        
        renderer = new THREE.WebGLRenderer({
            canvas: document.getElementById('threejs'),
            antialias: true
        })
        renderer.setSize(window.innerWidth, window.innerHeight)
        renderer.setPixelRatio(pixelRatio)
        renderer.setClearColor(0x203030)

        composer = new EffectComposer(renderer)

        camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.01, 100)
        camera.position.set(2, 2, 2)
        camera.getWorldDirection(camDirection)
        scene.add(camera)

        controls = new OrbitControls(camera, document.body)
        controls.enableDamping = true

        const renderPass = new RenderPass(scene, camera)
        composer.addPass(renderPass)

        const shader = {
            uniforms: {
                camPos: {value: camera.position},
                camDir: {value: camDirection},
                aspect: {value: window.innerWidth / window.innerHeight},
                time: {value: 0}
            },
            vertexShader: VS,
            fragmentShader: FS
        }
        const shaderPass = new ShaderPass(shader)
        composer.addPass(shaderPass)

        animation()
    }

    function animation()
    {
        controls.update()

        camera.getWorldDirection(camDirection)
        composer.passes[1].uniforms.camDir.value = camDirection
        composer.passes[1].uniforms.camPos.value = camera.position
        composer.passes[1].uniforms.time.value += 1
        
        composer.render()

        requestAnimationFrame(animation)
    }

    window.addEventListener('resize', resize)

    function resize()
    {
        composer.passes[1].uniforms.aspect.value = window.innerWidth / window.innerHeight

        renderer.setSize(window.innerWidth, window.innerHeight)
        renderer.setPixelRatio(pixelRatio)
    }
}