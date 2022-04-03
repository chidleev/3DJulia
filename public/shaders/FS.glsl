varying vec2 vUv;

uniform vec3 camPos;
uniform vec3 camDir;
uniform float aspect;
uniform float time;

const vec3 skyColor = vec3(0.5, 0.85, 1.);

const vec3 sunDir = normalize(vec3(1., 5., 3.));

const int numIterations = 10;

vec3 getRayDirection(float FOV);
vec2 boxIntersection(in vec3 ro, in vec3 rd, vec3 boxPosition, vec3 boxSize, out vec3 outNormal);
vec3 render( in vec3 ro, in vec3 rd, in vec4 c );

void main()
{
    vec3 rayDir = getRayDirection(90.);
    vec3 normal = vec3(0.);

    vec2 t = boxIntersection(camPos, rayDir, vec3(0., 0., 0.), vec3(2., 2., 2.), normal);

    //vec3 color = (t[0] >= 0.)? vec3(1. - (t[1] - t[0]) / 6.5) * skyColor : skyColor;
    vec4 c = vec4(0.25 + (sin(time / 11.) + 1.) / 4., 0.25 + (sin(time / 17.) + 1.) / 4., 0.25 + (sin(time / 23.) + 1.) / 4., 0.25 + (sin(time / 31.) + 1.) / 4.);
    vec3 color = render(camPos, rayDir, c);
    
    gl_FragColor = vec4(color, 1.);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////

vec3 getRayDirection(float FOV) {
    float camD = 1. / (2. * tan(radians(FOV) / 2.));
    vec3 camRight = normalize(cross(vec3(0., 1., 0.), camDir));
	vec3 camTop = normalize(cross(camRight, camDir));

    vec3 pixelPos = camPos + camD * camDir + (0.5 - vUv.x) * camRight + (0.5 - vUv.y) * camTop / aspect;
    
    return normalize(pixelPos - camPos);
}

vec2 boxIntersection( in vec3 ro, in vec3 rd, vec3 boxPosition, vec3 boxSize, out vec3 outNormal ) 
{
    ro -= boxPosition;
    vec3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes
    vec3 n = m*ro;   // can precompute if traversing a set of aligned boxes
    vec3 k = abs(m)*boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max( max( t1.x, t1.y ), t1.z );
    float tF = min( min( t2.x, t2.y ), t2.z );
    if( tN>tF || tF<0.0) return vec2(-1.0); // no intersection
    outNormal = -sign(rd)*step(t1.yzx,t1.xyz)*step(t1.zxy,t1.xyz);
    return vec2( tN, tF );
}

vec4 qsqr( in vec4 a ) // square a quaterion
{
    return vec4( a.x*a.x - a.y*a.y - a.z*a.z - a.w*a.w,
                 2.0*a.x*a.y,
                 2.0*a.x*a.z,
                 2.0*a.x*a.w );
}

float qlength2( in vec4 q )
{
    return dot(q,q);
}


float map( in vec3 p, out vec4 oTrap, in vec4 c )
{
    vec4 z = vec4(p,0.0);
    float md2 = 1.0;
    float mz2 = dot(z,z);

    vec4 trap = vec4(abs(z.xyz), dot(z,z));

    float n = 1.0;
    for( int i=0; i<numIterations; i++ )
    {
        // dz -> 2·z·dz, meaning |dz| -> 2·|z|·|dz|
        // Now we take the 2.0 out of the loop and do it at the end with an exp2
        md2 *= 4.0*mz2;
        // z  -> z^2 + c
        z = qsqr(z) + c;  

        trap = min( trap, vec4(abs(z.xyz),dot(z,z)) );

        mz2 = qlength2(z);

        if(mz2 > 4.0) break;

        n += 1.0;
    }
    
    oTrap = trap;

    return 0.25*sqrt(mz2/md2)*log(mz2);  // d = 0.5·|z|·log|z|/|z'|
}

vec3 calcNormal( in vec3 p, in vec4 c )
{
    vec4 z = vec4(p,0.0);

    // identity derivative
    mat4x4 J = mat4x4(1,0,0,0,  
                      0,1,0,0,  
                      0,0,1,0,  
                      0,0,0,1 );

  	for(int i=0; i<numIterations; i++)
    {
        // chain rule of jacobians (removed the 2 factor)
        J = J*mat4x4(z.x, -z.y, -z.z, -z.w, 
                     z.y,  z.x,  0.0,  0.0,
                     z.z,  0.0,  z.x,  0.0, 
                     z.w,  0.0,  0.0,  z.x);

        // z -> z2 + c
        z = qsqr(z) + c; 
        
        if(qlength2(z)>4.0) break;
    }

    return normalize( (J*z).xyz );
}

float intersect( in vec3 ro, in vec3 rd, out vec4 res, in vec4 c )
{
    vec4 tmp;
    float resT = -1.0;
	float maxd = 10.0;
    float h = 1.0;
    float t = 0.0;
    for( int i=0; i<300; i++ )
    {
        if( h<0.0001||t>maxd ) break;
	    h = map( ro+rd*t, tmp, c );
        t += h;
    }
    if( t<maxd ) { resT=t; res = tmp; }

	return resT;
}

float softshadow( in vec3 ro, in vec3 rd, float mint, float k, in vec4 c )
{
    float res = 1.0;
    float t = mint;
    for( int i=0; i<64; i++ )
    {
        vec4 kk;
        float h = map(ro + rd*t, kk, c);
        res = min( res, k*h/t );
        if( res<0.001 ) break;
        t += clamp( h, 0.01, 0.5 );
    }
    return clamp(res,0.0,1.0);
}

vec3 render( in vec3 ro, in vec3 rd, in vec4 c )
{
	const vec3 sun = sunDir;
    
	vec4 tra;
	vec3 col;

    float t = intersect( ro, rd, tra, c );
    
    if( t < 0.0 )
    {
     	col = vec3(0.7,0.9,1.0)*(0.7+0.3*rd.y);
		col += vec3(0.8,0.7,0.5)*pow( clamp(dot(rd,sun),0.0,1.0), 48.0 );
	}
	else
	{
        vec3 mate = vec3(.1,0.3,0.2)*0.3;
		//mate.x = 1.0-10.0*tra.x;
        
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal( pos, c );
        
		float occ = clamp(2.5*tra.w-0.15,0.0,1.0);
		

        col = vec3(0.0);

        // sky
        {
        float co = clamp( dot(-rd,nor), 0.0, 1.0 );
        vec3 ref = reflect( rd, nor );
        //float sha = softshadow( pos+0.0005*nor, ref, 0.001, 4.0, c );
        float sha = occ;
        sha *= smoothstep( -0.1, 0.1, ref.y );
        float fre = 0.1 + 0.9*pow(1.0-co,5.0);
            
		col  = mate*0.3*vec3(0.8,0.9,1.0)*(0.6+0.4*nor.y)*occ;
		col +=  2.0*0.3*vec3(0.8,0.9,1.0)*(0.6+0.4*nor.y)*sha*fre;
        }

        // sun
        {
        const vec3 lig = sun;
        float dif = clamp( dot( lig, nor ), 0.0, 1.0 );
        float sha = softshadow( pos, lig, 0.001, 64.0, c );
        vec3 hal = normalize( -rd+lig );
        float co = clamp( dot(hal,lig), 0.0, 1.0 );
        float fre = 0.04 + 0.96*pow(1.0-co,5.0);
        float spe = pow(clamp(dot(hal,nor), 0.0, 1.0 ), 32.0 );
        col += mate*3.5*vec3(1.00,0.90,0.70)*dif*sha;
        col +=  7.0*3.5*vec3(1.00,0.90,0.70)*spe*dif*sha*fre;
        }

        // extra fill
        {
        const vec3 lig = vec3( -0.707, 0.000, -0.707 );
		float dif = clamp(0.5+0.5*dot(lig,nor), 0.0, 1.0 );
        col += mate* 1.5*vec3(0.14,0.14,0.14)*dif*occ;
        }
        
        // fake SSS
        {
        float fre = clamp( 1.+dot(rd,nor), 0.0, 1.0 );
        col += mate* mate*0.6*fre*fre*(0.2+0.8*occ);
        }
    }

	return pow( col, vec3(0.4545) );
}