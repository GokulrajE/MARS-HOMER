shader_type canvas_item;
uniform float swim_clock=0.0;
uniform float reaction=0.0;
uniform int actor_style=0;
void fragment() {
 vec2 uv=UV;
 float straw=1.0-smoothstep(.05,.35,uv.x);
 uv.y+=sin(swim_clock*9.0+uv.x*12.0)*.018*straw;
 // Local soft deformation gives clothing and appendages their own motion.
 if(actor_style==1) { // Chutki's pigtails and skirt.
  float hair=exp(-pow((uv.x-.46)*9.0,2.0)-pow((uv.y-.30)*8.0,2.0));
  uv.y+=sin(swim_clock*6.0+uv.x*9.0)*.018*hair;
 } else if(actor_style==2) { // Raju's dangling feet kick gently.
  float feet=smoothstep(.70,.90,uv.y)*(1.0-smoothstep(.65,.80,uv.x));
  uv.x+=sin(swim_clock*7.0)*.018*feet;
 } else if(actor_style==3) { // Bean's tie flutters separately.
  float tie=exp(-pow((uv.x-.51)*8.0,2.0)-pow((uv.y-.33)*12.0,2.0));
  uv.y+=sin(swim_clock*7.0+uv.x*12.0)*.022*tie;
 } else if(actor_style>=4) { // Raised hands accent a successful passage.
  float hand=smoothstep(.76,.88,uv.x)*(1.0-smoothstep(.36,.50,uv.y));
  uv.y+=sin(swim_clock*10.0)*.025*reaction*hand;
 }
 float cloth=exp(-pow((uv.x-.50)*9.0,2.0)-pow((uv.y-.55)*9.0,2.0));
 uv.x+=sin(swim_clock*4.0+uv.y*9.0)*.008*cloth;
 COLOR=texture(TEXTURE,uv);
}
