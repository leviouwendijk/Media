#ifndef MEDIA_LTC_BRIDGE_H
#define MEDIA_LTC_BRIDGE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    int32_t hours;
    int32_t minutes;
    int32_t seconds;
    int32_t frame;
    int32_t drop_frame;
    int32_t reverse;
    int64_t sample_start;
    int64_t sample_end;
    double volume;
} MediaLTCDecodedFrame;

void *media_ltc_decoder_create(
    int32_t sample_rate,
    double fps,
    int32_t queue_size
);

void media_ltc_decoder_destroy(
    void *decoder
);

void media_ltc_decoder_write_float(
    void *decoder,
    const float *samples,
    size_t count,
    int64_t sample_offset
);

int32_t media_ltc_decoder_read(
    void *decoder,
    MediaLTCDecodedFrame *frame
);

void *media_ltc_encoder_create(
    int32_t sample_rate,
    double fps
);

void media_ltc_encoder_destroy(
    void *encoder
);

void media_ltc_encoder_set_time(
    void *encoder,
    int32_t hours,
    int32_t minutes,
    int32_t seconds,
    int32_t frame
);

size_t media_ltc_encoder_max_samples(
    void *encoder
);

int32_t media_ltc_encoder_encode_frame(
    void *encoder,
    float *samples,
    size_t capacity
);

#ifdef __cplusplus
}
#endif

#endif
