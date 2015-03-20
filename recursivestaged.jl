using DevIL
ilInit()
ilBindImage(ilGenImage())
ilLoadImage("data/grid2.png")
ilGetInteger(IL_IMAGE_WIDTH)
ilDeleteImage(ilGetInteger(IL_CUR_IMAGE))
ilShutDown()