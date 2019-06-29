#define YUV420_data(v) (Caml_ba_data_val(Field(v,0)))
#define YUV420_y_stride(v) (Int_val(Field(v,1)))
#define YUV420_uv_stride(v) (Int_val(Field(v,2)))
#define YUV420_width(v) (Int_val(Field(v,3)))
#define YUV420_height(v) (Int_val(Field(v,4)))
#define YUV420_alpha(v) (Is_block(Field(v,5))?Caml_ba_data_val(Field(Field(v,5),0)):NULL)

typedef struct
{
  int width;
  int height;
  unsigned char *data;
  int y_stride;
  int uv_stride;
  unsigned char *alpha;
} yuv420;

static void yuv420_of_value(yuv420 *yuv, value v)
{
  yuv->data = YUV420_data(v);
  yuv->y_stride = YUV420_y_stride(v);
  yuv->uv_stride = YUV420_uv_stride(v);
  yuv->width = YUV420_width(v);
  yuv->height = YUV420_height(v);
  yuv->alpha = YUV420_alpha(v);
}

#define Y(yuv,i,j) yuv.data[j*yuv.y_stride+i]
#define U(yuv,i,j) yuv.data[yuv.height*yuv.y_stride+(j/2)*yuv.uv_stride+(i/2)]
#define V(yuv,i,j) yuv.data[yuv.height*yuv.y_stride+(yuv.height/2+(j/2))*yuv.uv_stride+(i/2)]
#define A(yuv,i,j) yuv.alpha[j*yuv.y_stride+i]
