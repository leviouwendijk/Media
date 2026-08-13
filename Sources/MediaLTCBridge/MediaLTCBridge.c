#include "MediaLTCBridge.h"

#include <ltc.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    LTCDecoder *decoder;
} MediaLTCDecoderBox;

typedef struct {
    LTCEncoder *encoder;
    ltcsnd_sample_t *buffer;
    size_t capacity;
} MediaLTCEncoderBox;

static enum LTC_TV_STANDARD media_ltc_standard(
    double fps
) {
    if (fabs(fps - 25.0) < 0.01) {
        return LTC_TV_625_50;
    }

    if (fabs(fps - 24.0) < 0.01) {
        return LTC_TV_FILM_24;
    }

    return LTC_TV_525_60;
}

void *media_ltc_decoder_create(
    int32_t sample_rate,
    double fps,
    int32_t queue_size
) {
    if (sample_rate <= 0 || fps <= 0.0) {
        return NULL;
    }

    int apv = (int)llround(
        (double)sample_rate / fps
    );

    if (apv <= 0) {
        return NULL;
    }

    LTCDecoder *decoder = ltc_decoder_create(
        apv,
        queue_size > 0
            ? queue_size
            : 32
    );

    if (decoder == NULL) {
        return NULL;
    }

    MediaLTCDecoderBox *box = malloc(
        sizeof(
            MediaLTCDecoderBox
        )
    );

    if (box == NULL) {
        ltc_decoder_free(
            decoder
        );

        return NULL;
    }

    box->decoder = decoder;

    return box;
}

void media_ltc_decoder_destroy(
    void *decoder
) {
    if (decoder == NULL) {
        return;
    }

    MediaLTCDecoderBox *box = decoder;

    if (box->decoder != NULL) {
        ltc_decoder_free(
            box->decoder
        );
    }

    free(
        box
    );
}

void media_ltc_decoder_write_float(
    void *decoder,
    const float *samples,
    size_t count,
    int64_t sample_offset
) {
    if (decoder == NULL || samples == NULL || count == 0) {
        return;
    }

    MediaLTCDecoderBox *box = decoder;

    ltc_decoder_write_float(
        box->decoder,
        (float *)samples,
        count,
        sample_offset
    );
}

int32_t media_ltc_decoder_read(
    void *decoder,
    MediaLTCDecodedFrame *output
) {
    if (decoder == NULL || output == NULL) {
        return 0;
    }

    MediaLTCDecoderBox *box = decoder;

    LTCFrameExt frame;

    if (!ltc_decoder_read(
        box->decoder,
        &frame
    )) {
        return 0;
    }

    SMPTETimecode timecode;

    memset(
        &timecode,
        0,
        sizeof(
            timecode
        )
    );

    ltc_frame_to_time(
        &timecode,
        &frame.ltc,
        0
    );

    output->hours = timecode.hours;
    output->minutes = timecode.mins;
    output->seconds = timecode.secs;
    output->frame = timecode.frame;
    output->drop_frame = frame.ltc.dfbit
        ? 1
        : 0;
    output->reverse = frame.reverse
        ? 1
        : 0;
    output->sample_start = frame.off_start;
    output->sample_end = frame.off_end;
    output->volume = frame.volume;

    return 1;
}

void *media_ltc_encoder_create(
    int32_t sample_rate,
    double fps
) {
    if (sample_rate <= 0 || fps <= 0.0) {
        return NULL;
    }

    LTCEncoder *encoder = ltc_encoder_create(
        sample_rate,
        fps,
        media_ltc_standard(
            fps
        ),
        0
    );

    if (encoder == NULL) {
        return NULL;
    }

    MediaLTCEncoderBox *box = malloc(
        sizeof(
            MediaLTCEncoderBox
        )
    );

    if (box == NULL) {
        ltc_encoder_free(
            encoder
        );

        return NULL;
    }

    box->encoder = encoder;
    box->capacity = ltc_encoder_get_buffersize(
        encoder
    );
    box->buffer = malloc(
        box->capacity
    );

    if (box->buffer == NULL) {
        ltc_encoder_free(
            encoder
        );

        free(
            box
        );

        return NULL;
    }

    return box;
}

void media_ltc_encoder_destroy(
    void *encoder
) {
    if (encoder == NULL) {
        return;
    }

    MediaLTCEncoderBox *box = encoder;

    if (box->encoder != NULL) {
        ltc_encoder_free(
            box->encoder
        );
    }

    free(
        box->buffer
    );

    free(
        box
    );
}

void media_ltc_encoder_set_time(
    void *encoder,
    int32_t hours,
    int32_t minutes,
    int32_t seconds,
    int32_t frame
) {
    if (encoder == NULL) {
        return;
    }

    MediaLTCEncoderBox *box = encoder;

    SMPTETimecode timecode;

    memset(
        &timecode,
        0,
        sizeof(
            timecode
        )
    );

    timecode.hours = (unsigned char)hours;
    timecode.mins = (unsigned char)minutes;
    timecode.secs = (unsigned char)seconds;
    timecode.frame = (unsigned char)frame;

    ltc_encoder_set_timecode(
        box->encoder,
        &timecode
    );
}

size_t media_ltc_encoder_max_samples(
    void *encoder
) {
    if (encoder == NULL) {
        return 0;
    }

    MediaLTCEncoderBox *box = encoder;

    return box->capacity;
}

int32_t media_ltc_encoder_encode_frame(
    void *encoder,
    float *samples,
    size_t capacity
) {
    if (encoder == NULL || samples == NULL) {
        return 0;
    }

    MediaLTCEncoderBox *box = encoder;

    if (capacity < box->capacity) {
        return 0;
    }

    ltc_encoder_encode_frame(
        box->encoder
    );

    int count = ltc_encoder_copy_buffer(
        box->encoder,
        box->buffer
    );

    if (count <= 0) {
        return 0;
    }

    for (int index = 0; index < count; index++) {
        samples[index] = (
            (float)box->buffer[index]
            - 128.0f
        ) / 128.0f;
    }

    ltc_encoder_inc_timecode(
        box->encoder
    );

    return count;
}
