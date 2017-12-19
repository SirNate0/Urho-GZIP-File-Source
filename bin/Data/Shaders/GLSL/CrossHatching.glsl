#include "Uniforms.glsl"
#include "Samplers.glsl"
#include "Transform.glsl"
#include "ScreenPos.glsl"
#include "Lighting.glsl"
#include "Fog.glsl"

#ifdef NORMALMAP
    varying vec4 vTexCoord;
    varying vec4 vTangent;
#else
    varying vec2 vTexCoord;
#endif
varying vec3 vNormal;
varying vec4 vWorldPos;
#ifdef VERTEXCOLOR
    varying vec4 vColor;
#endif
#ifdef PERPIXEL
    #ifdef SHADOW
        #ifndef GL_ES
            varying vec4 vShadowPos[NUMCASCADES];
        #else
            varying highp vec4 vShadowPos[NUMCASCADES];
        #endif
    #endif
    #ifdef SPOTLIGHT
        varying vec4 vSpotPos;
    #endif
    #ifdef POINTLIGHT
        varying vec3 vCubeMaskVec;
    #endif
#else
//     vec3 vVertexLight = vec3(1.0,10.0,1.0);
    varying vec3 vVertexLight;
//    varying vec4 vScreenPos;
    #ifdef ENVCUBEMAP
        varying vec3 vReflectionVec;
    #endif
    #if defined(LIGHTMAP) || defined(AO)
        varying vec2 vTexCoord2;
    #endif
#endif

//        varying vec4 vSpotPos;
    varying vec4 vScreenPos;
varying float depth;
//varying float nDotVP;
//uniform vec2 repeat;

void VS()
{
    mat4 modelMatrix = iModelMatrix;
    vec3 worldPos = GetWorldPos(modelMatrix);
    gl_Position = GetClipPos(worldPos);
    vNormal = GetWorldNormal(modelMatrix);
    vWorldPos = vec4(worldPos, GetDepth(gl_Position));

    #ifdef VERTEXCOLOR
        vColor = iColor;
    #endif

    #ifdef NORMALMAP
        vec3 tangent = GetWorldTangent(modelMatrix);
        vec3 bitangent = cross(tangent, vNormal) * iTangent.w;
        vTexCoord = vec4(GetTexCoord(iTexCoord), bitangent.xy);
        vTangent = vec4(tangent, bitangent.z);
    #else
        vTexCoord = GetTexCoord(iTexCoord);
    #endif

    #ifdef PERPIXEL
        // Per-pixel forward lighting
        vec4 projWorldPos = vec4(worldPos, 1.0);

        #ifdef SHADOW
            // Shadow projection: transform from world space to shadow space
            for (int i = 0; i < NUMCASCADES; i++)
                vShadowPos[i] = GetShadowPos(i, vNormal, projWorldPos);
        #endif

        #ifdef SPOTLIGHT
            // Spotlight projection: transform from world space to projector texture coordinates
            vSpotPos = projWorldPos * cLightMatrices[0];
        #endif
    
        #ifdef POINTLIGHT
            vCubeMaskVec = (worldPos - cLightPos.xyz) * mat3(cLightMatrices[0][0].xyz, cLightMatrices[0][1].xyz, cLightMatrices[0][2].xyz);
        #endif
    #else
        // Ambient & per-vertex lighting
        #if defined(LIGHTMAP) || defined(AO)
            // If using lightmap, disregard zone ambient light
            // If using AO, calculate ambient in the PS
            vVertexLight = vec3(0.0, 0.0, 0.0);
            vTexCoord2 = iTexCoord1;
        #else
            vVertexLight = GetAmbient(GetZonePos(worldPos));
        #endif
        
        #ifdef NUMVERTEXLIGHTS
            for (int i = 0; i < NUMVERTEXLIGHTS; ++i)
                vVertexLight += GetVertexLight(i, worldPos, vNormal) * cVertexLights[i * 3].rgb;
        #endif
        
        vScreenPos = GetScreenPos(gl_Position);

        #ifdef ENVCUBEMAP
            vReflectionVec = worldPos - cCameraPos;
        #endif
    #endif
                //depth = ( length( position.xyz ) / 90. );
                depth = vWorldPos.w;//.5 + .5 * depth;

                //nDotVP = max( 0., dot( vNormal, normalize( vec3( vVertexLight.xyz ) ) ) );

    #ifdef EDGE
      vScreenPos = GetScreenPos(gl_Position);
    #endif
 
    #ifdef BASE
        vec3 n = iNormal+vec3(1.0);
        n*=0.5;
        vColor = vec4(n,1.0);
    #endif
}

/*
uniform sampler2D hatch1;
uniform sampler2D hatch2;
uniform sampler2D hatch3;
uniform sampler2D hatch4;
uniform sampler2D hatch5;
uniform sampler2D hatch6;*/

#define hatch1 sDiffMap 
#define hatch2 sNormalMap 
#define hatch3 sSpecMap 
#define hatch4 sEmissiveMap 
#define hatch5 sEnvMap 
#define hatch6 sLightRampMap 
#define paper sEmissiveMap 
/*
uniform samplerCube sDiffCubeMap;
uniform sampler2D sNormalMap;
uniform sampler2D sSpecMap;
uniform sampler2D sEmissiveMap;
uniform sampler2D sEnvMap;
uniform samplerCube sEnvCubeMap;
uniform sampler2D sLightRampMap;*/
/*
            uniform float ambientWeight;
            uniform float diffuseWeight;
            uniform float rimWeight;
            uniform float specularWeight;
            uniform float shininess;
            uniform int invertRim;
            uniform int solidRender;
            uniform float showOutline;
            uniform vec4 inkColor;
            uniform vec2 resolution;
            uniform vec2 bkgResolution;
            uniform vec3 lightPosition;
            vec3 color = vec3( 1., 0., 1. );
            vec3 lightColor = vec3( 1. );
*/

#ifdef COMPILEPS
float ambientWeight = 0.5;
float diffuseWeight = 1.0;
float rimWeight = 0.46;
float specularWeight = 1.0;
float shininess = 0.49;
int invertRim = 0;
int solidRender = 0;
float showOutline = 0.01;
vec4 inkColor = vec4(0.282, 0.282, 0.64, 0.5);
vec2 resolution = vec2(256,256);
vec2 bkgResolution = vec2(256,256);
//vec3 lightPosition;
vec3 color = vec3( 1., 1., 1. );
vec3 lightColor = vec3( 1. );

float nDotVP;


float color_difference(in vec4 sc, in vec4 nc){
  return abs(sc.r-nc.r)+abs(sc.g-nc.g)+abs(sc.b-nc.b);
}
 
vec4 get_pixel(in sampler2D tex, in vec2 coords, in float dx, in float dy) {
 return texture2D(tex,coords + vec2(dx, dy));
}
 
// returns pixel color
float IsEdge(in sampler2D tex, in vec2 coords){
  float dxtex = 1.0 / 1920.0; //image width;
  float dytex = 1.0 / 1080.0; //image height;
  float cd[8];
 
  vec4 sc = get_pixel(tex,coords,float(0)*dxtex,float(0)*dytex);
  cd[0] = color_difference( sc, get_pixel(tex,coords,float(-1)*dxtex,float(-1)*dytex) );//color of itself
  cd[1] = color_difference( sc, get_pixel(tex,coords,float(-1)*dxtex,float(0)*dytex) );
  cd[2] = color_difference( sc, get_pixel(tex,coords,float(-1)*dxtex,float(1)*dytex) );
  cd[3] = color_difference( sc, get_pixel(tex,coords,float(0)*dxtex,float(1)*dytex) );
 
  vec4 alt1 = get_pixel(tex,coords,float(1)*dxtex,float(1)*dytex);
  vec4 alt2 = get_pixel(tex,coords,float(1)*dxtex,float(0)*dytex);
  vec4 alt3 = get_pixel(tex,coords,float(1)*dxtex,float(-1)*dytex);
  vec4 alt4 = get_pixel(tex,coords,float(0)*dxtex,float(-1)*dytex);
 
  if( length(alt1.rgb) < 0.1 ){ cd[4] = color_difference( sc, alt1 ); }else{ cd[4]=0.0; }
  if( length(alt2.rgb) < 0.1 ){ cd[5] = color_difference( sc, alt2 ); }else{ cd[5]=0.0; }
  if( length(alt3.rgb) < 0.1 ){ cd[6] = color_difference( sc, alt3 ); }else{ cd[6]=0.0; }
  if( length(alt4.rgb) < 0.1 ){ cd[7] = color_difference( sc, alt4 ); }else{ cd[7]=0.0; }
 
  return cd[0]+cd[1]+cd[2]+cd[3]+cd[4]+cd[5]+cd[6]+cd[7];
}

vec4 shade(vec3 lightDir) {
                
                float diffuse = nDotVP;
                float specular = 0.;
                float ambient = 1.;

                vec3 n = normalize( vNormal );

                vec3 r = -reflect(-lightDir /*lightPosition*/, n);
                r = normalize(r);
                vec3 v = -vWorldPos.xyz;
                v = normalize(v);
                float nDotHV = max( 0., dot( r, v ) );

                if( nDotVP != 0. ) specular = pow ( nDotHV, shininess );
                float rim = max( 0., abs( dot( n, normalize( -vWorldPos.xyz ) ) ) );
                if( invertRim == 1 ) rim = 1. - rim;

                float shading = ambientWeight * ambient + diffuseWeight * diffuse + rimWeight * rim + specularWeight * specular;

                if( solidRender == 1 ) 
			return vec4( shading );

                vec4 c;
                float step = 1. / 6.;
		vec2 vUv = vWorldPos.xy;
                if( shading <= step ){   
                    c = mix( texture2D( hatch6, vUv ), texture2D( hatch5, vUv ), 6. * shading );
                }
                if( shading > step && shading <= 2. * step ){
                    c = mix( texture2D( hatch5, vUv ), texture2D( hatch4, vUv) , 6. * ( shading - step ) );
                }
                if( shading > 2. * step && shading <= 3. * step ){
                    c = mix( texture2D( hatch4, vUv ), texture2D( hatch3, vUv ), 6. * ( shading - 2. * step ) );
                }
                if( shading > 3. * step && shading <= 4. * step ){
                    c = mix( texture2D( hatch3, vUv ), texture2D( hatch2, vUv ), 6. * ( shading - 3. * step ) );
                }
                if( shading > 4. * step && shading <= 5. * step ){
                    c = mix( texture2D( hatch2, vUv ), texture2D( hatch1, vUv ), 6. * ( shading - 4. * step ) );
                }
                if( shading > 5. * step ){
                    c = mix( texture2D( hatch1, vUv ), vec4( 1. ), 6. * ( shading - 5. * step ) );
                }

                vec4 src = mix( mix( inkColor, vec4( 1. ), c.r ), c, .5 );
                //c = 1. - ( 1. - src ) * ( 1. - dst );
                //c = vec4( min( src.r, dst.r ), min( src.g, dst.g ), min( src.b, dst.b ), 1. );

                //c = vec4( gl_FragCoord.x / resolution.x, gl_FragCoord.y / resolution.y, 0., 1. );

                return src;
            }
#endif

void PS()
{







    // Get material diffuse albedo
    #ifdef DIFFMAP
        vec4 diffInput = texture2D(sDiffMap, vTexCoord.xy);
        #ifdef ALPHAMASK
            if (diffInput.a < 0.5)
                discard;
        #endif
        vec4 diffColor = cMatDiffColor * diffInput;
    #else
        vec4 diffColor = cMatDiffColor;
    #endif

    #ifdef VERTEXCOLOR
        diffColor *= vColor;
    #endif
    
    // Get material specular albedo
    #ifdef SPECMAP
        vec3 specColor = cMatSpecColor.rgb * texture2D(sSpecMap, vTexCoord.xy).rgb;
    #else
        vec3 specColor = cMatSpecColor.rgb;
    #endif

    // Get normal
    #ifdef NORMALMAP
        mat3 tbn = mat3(vTangent.xyz, vec3(vTexCoord.zw, vTangent.w), vNormal);
        vec3 normal = normalize(tbn * DecodeNormal(texture2D(sNormalMap, vTexCoord.xy)));
    #else
        vec3 normal = normalize(vNormal);
    #endif

    // Get fog factor
    #ifdef HEIGHTFOG
        float fogFactor = GetHeightFogFactor(vWorldPos.w, vWorldPos.y);
    #else
        float fogFactor = GetFogFactor(vWorldPos.w);
    #endif

    #if defined(PERPIXEL)
        // Per-pixel forward lighting
        vec3 lightColor;
        vec3 lightDir;
        vec3 finalColor;

        float diff = GetDiffuse(normal, vWorldPos.xyz, lightDir);

        #ifdef SHADOW
            diff *= GetShadow(vShadowPos, vWorldPos.w);
        #endif
    
        #if defined(SPOTLIGHT)
            lightColor = vSpotPos.w > 0.0 ? texture2DProj(sLightSpotMap, vSpotPos).rgb * cLightColor.rgb : vec3(0.0, 0.0, 0.0);
        #elif defined(CUBEMASK)
            lightColor = textureCube(sLightCubeMap, vCubeMaskVec).rgb * cLightColor.rgb;
        #else
            lightColor = cLightColor.rgb;
        #endif
    
        #ifdef SPECULAR
            float spec = GetSpecular(normal, cCameraPosPS - vWorldPos.xyz, lightDir, cMatSpecColor.a);
            finalColor = diff * lightColor * (diffColor.rgb + spec * specColor * cLightColor.a);
        #else
            finalColor = diff * lightColor * diffColor.rgb;
        #endif

        #ifdef AMBIENT
            finalColor += cAmbientColor.rgb * diffColor.rgb;
            finalColor += cMatEmissiveColor;
            gl_FragColor = vec4(GetFog(finalColor, fogFactor), diffColor.a);
        #else
            gl_FragColor = vec4(GetLitFog(finalColor, fogFactor), diffColor.a);
        #endif
    #elif defined(PREPASS)
        // Fill light pre-pass G-Buffer
        float specPower = cMatSpecColor.a / 255.0;

        gl_FragData[0] = vec4(normal * 0.5 + 0.5, specPower);
        gl_FragData[1] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #elif defined(DEFERRED)
        // Fill deferred G-buffer
        float specIntensity = specColor.g;
        float specPower = cMatSpecColor.a / 255.0;

        vec3 finalColor = vVertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * cAmbientColor.rgb * diffColor.rgb;
        #endif

        #ifdef ENVCUBEMAP
            finalColor += cMatEnvMapColor * textureCube(sEnvCubeMap, reflect(vReflectionVec, normal)).rgb;
        #endif
        #ifdef LIGHTMAP
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * diffColor.rgb;
        #endif
        #ifdef EMISSIVEMAP
            finalColor += cMatEmissiveColor * texture2D(sEmissiveMap, vTexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif

        gl_FragData[0] = vec4(GetFog(finalColor, fogFactor), 1.0);
        gl_FragData[1] = fogFactor * vec4(diffColor.rgb, specIntensity);
        gl_FragData[2] = vec4(normal * 0.5 + 0.5, specPower);
        gl_FragData[3] = vec4(EncodeDepth(vWorldPos.w), 0.0);
    #else
        // Ambient & per-vertex lighting
        vec3 finalColor = vVertexLight * diffColor.rgb;
        #ifdef AO
            // If using AO, the vertex light ambient is black, calculate occluded ambient here
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * cAmbientColor.rgb * diffColor.rgb;
        #endif
        
        #ifdef MATERIAL
            // Add light pre-pass accumulation result
            // Lights are accumulated at half intensity. Bring back to full intensity now
            vec4 lightInput = 2.0 * texture2DProj(sLightBuffer, vScreenPos);
            vec3 lightSpecColor = lightInput.a * lightInput.rgb / max(GetIntensity(lightInput.rgb), 0.001);

            finalColor += lightInput.rgb * diffColor.rgb + lightSpecColor * specColor;
        #endif

        #ifdef ENVCUBEMAP
            finalColor += cMatEnvMapColor * textureCube(sEnvCubeMap, reflect(vReflectionVec, normal)).rgb;
        #endif
        #ifdef LIGHTMAP
            finalColor += texture2D(sEmissiveMap, vTexCoord2).rgb * diffColor.rgb;
        #endif
        #ifdef EMISSIVEMAP
            finalColor += cMatEmissiveColor * texture2D(sEmissiveMap, vTexCoord.xy).rgb;
        #else
            finalColor += cMatEmissiveColor;
        #endif

        gl_FragColor = vec4(GetFog(finalColor, fogFactor), diffColor.a);
    #endif


    #ifdef BASE
        vec4 diffColor = vColor;
        gl_FragColor = diffColor;
	return;
    #endif
 
    #ifdef EDGE
      vec4 color = vec4(0.0,0.0,0.0,1.0);
      if(IsEdge(sEnvMap,vScreenPos.xy / vScreenPos.w)>=0.75){
        color.rgba = vec4(1.0);
        //color = get_pixel(sEnvMap,vScreenPos.xy / vScreenPos.w,float(0)*(1.0/1920.0),float(0)*(1.0/1080.0));
      }
	else
		color = get_pixel(sEnvMap,vScreenPos.xy / vScreenPos.w,float(0)*(1.0/1920.0),float(0)*(1.0/1080.0));
      gl_FragColor = color;
      gl_FragColor = vec4(vec3(1.0) - color.xyz, 1.0);
	return;
    #endif


	nDotVP = max( 0., dot( vNormal, normalize( vec3( lightDir.xyz ) ) ) );

	vec2 nUV = vec2( mod( gl_FragCoord.x, bkgResolution.x ) / bkgResolution.x, mod( gl_FragCoord.y, bkgResolution.y ) / bkgResolution.y );
        vec4 dst = vec4(1.);
//	vec4 dst = vec4( vec3(1) - texture2D( paper, nUV ).rgb, 1. );
        vec4 src;

        //if( showOutline == 1 ) src = .5 * inkColor;
        //else src = shade();
        src = ( .5 * inkColor ) * vec4( showOutline ) + vec4( 1. - showOutline ) * shade(-lightDir);

        vec4 c = src * dst;

        gl_FragColor = vec4( c.rgb, 1.1 - c.r ) + gl_FragColor;
//        gl_FragColor = vec4( lightDir, 1. );
//        gl_FragColor = vec4( vec3(depth), 1. );
//        gl_FragColor = dst;
//        gl_FragColor = src;
//	gl_FragColor = shade(lightDir);
	return;

}
