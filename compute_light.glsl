#[compute]
#version 450
layout(local_size_x = 32,local_size_y = 32) in;

layout(set = 0, binding = 0, r8) uniform restrict readonly image2D mapImage;
layout(set = 1, binding = 0, rgba8) uniform restrict writeonly image2D outputImage;

struct light{
    float x;
    float y;
    uint range;
    float facing_angle_x;
    float facing_angle_y;
    float max_dot;
};


layout(set = 2, binding = 0, std430) buffer Lights{
    light data[];
} lights;

// layout(push_constant, std430) uniform Params {
// 	uint max_light;
//     //used to pre-check where any light can actually hit by telling the pixels the info
//     uint prepass_id;
//     float x;
//     float y;

// } params;



//hmmm fancy
float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   
const float seed=51.12715;

float gold_noise(in vec2 xy){
       return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}

float length_squared(vec2 inp){
    return (inp.x*inp.x)+(inp.y*inp.y);
}


bool reach_goal(vec2 from, vec2 to,light light_data){
    if(
        length_squared(to-from)>light_data.range*light_data.range||
        (light_data.max_dot!=0&&dot(normalize(from-to),vec2(light_data.facing_angle_x,light_data.facing_angle_y))<light_data.max_dot)
    ) return false;

    vec2 slope=normalize(to-from);
    vec2 current=from;
    uint i=0;
    while(length_squared(current-to)>1.0&&i<light_data.range){
        i++;
        if(imageLoad(mapImage,ivec2(current*0.125)).r!=0||i==light_data.range) return false;
        current+=slope;
    }
    
    // if(length(current-to)>20.0) return false;
    return true;
}

const float max_alpha=0.75;

void main(){
    vec2 from =vec2(gl_GlobalInvocationID.x,gl_GlobalInvocationID.y);
    // if(from.x<0||from.y<0||from.x>64||from.y>64) return;
    imageStore(outputImage,ivec2(from),vec4(0,0,0,0));
    float final_alpha=0.0;
    uint hit_by_lights=0;
    for(uint i=0;i<lights.data.length();i++){
        light current=lights.data[i];
        if(current.range==0) break;
        
        if(reach_goal(from,vec2(current.x,current.y)*8.0,current)){
            hit_by_lights++;
            
            final_alpha=mix(final_alpha,1.0,1.0-floor((distance(from,vec2(current.x,current.y)*8.0)/current.range)*8.0)*0.125);
        }
    }
    if(hit_by_lights==0) return;
    // imageStore(outputImage,ivec2(from),vec4(1.0,1.0,1.0,max_alpha*(max(gold_noise(from)*0.0625+1.0,1.0)-final_alpha)));
    imageStore(outputImage,ivec2(from),vec4(1.0,1.0,1.0,max_alpha*final_alpha));
}