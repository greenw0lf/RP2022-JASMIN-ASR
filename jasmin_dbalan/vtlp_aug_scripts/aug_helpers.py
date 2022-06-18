import librosa
import numpy as np


def get_augment_range_by_coverage(data, zone, coverage):
    zone_start, zone_end = int(len(data) * zone[0]), int(len(data) * zone[1])
    zone_size = zone_end - zone_start

    target_size = int(zone_size * coverage)
    last_start = zone_start + int(zone_size * (1 - coverage))

    if zone_start == last_start:
        start_pos = zone_start
        end_pos = zone_end
    else:
        start_pos = np.random.randint(zone_start, last_start)
        end_pos = start_pos + target_size

    return start_pos, end_pos


def get_random_factor(lower_bound, upper_bound, dtype="float"):
    if dtype == "int":
        return np.random.randint(lower_bound, upper_bound)

    return np.random.uniform(lower_bound, upper_bound)
    # http://www.cs.toronto.edu/~hinton/absps/perturb.pdf


# https://github.com/YerevaNN/Spoken-language-identification/blob/master/augment_data.py#L26
def manipulate(data, start_pos, end_pos, sampling_rate, warp_factor):
    audio = data[start_pos:end_pos]
    stft = librosa.core.stft(audio)
    freq_dim, time_dim = stft.shape
    data_type = type(stft[0][0])

    factors = get_scale_factors(freq_dim, sampling_rate, alpha=warp_factor)
    factors *= (freq_dim - 1) / max(factors)
    new_stft = np.zeros([freq_dim, time_dim], dtype=data_type)

    for i in range(freq_dim):
        # first and last freq
        if i == 0 or i + 1 >= freq_dim:
            new_stft[i, :] += stft[i, :]
        else:
            warp_up = factors[i] - np.floor(factors[i])
            warp_down = 1 - warp_up
            pos = int(np.floor(factors[i]))

            new_stft[pos, :] += warp_down * stft[i, :]
            new_stft[pos + 1, :] += warp_up * stft[i, :]

    aug_data = librosa.core.istft(new_stft)
    return np.concatenate((data[:start_pos], aug_data, data[end_pos:]), axis=0).astype(
        type(data[0])
    )


# https://pdfs.semanticscholar.org/3de0/616eb3cd4554fdf9fd65c9c82f2605a17413.pdf
# http://www.cs.toronto.edu/~hinton/absps/perturb.pdf
def get_scale_factors(freq_dim, sampling_rate, fhi=4800, alpha=0.9):
    factors = []
    freqs = np.linspace(0, 1, freq_dim)

    scale = fhi * min(alpha, 1)
    f_boundary = scale / alpha
    half_sr = sampling_rate / 2

    for f in freqs:
        f *= sampling_rate
        if f <= f_boundary:
            factors.append(f * alpha)
        else:
            warp_freq = half_sr - (half_sr - scale) / (half_sr - scale / alpha) * (
                half_sr - f
            )
            factors.append(warp_freq)

    return np.array(factors)
