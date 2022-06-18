import sys
import aug_helpers as aug


class VtlpAug:
    def __init__(
        self,
        sampling_rate,
        zone=(0.2, 0.8),
        coverage=0.1,
        fhi=4800,
        factor_range=(0.9, 1.1),
    ):
        self.sampling_rate = sampling_rate
        self.fhi = fhi
        self.factor_range = factor_range
        self.zone = zone
        self.coverage = coverage

    def augment(self, data):
        """
        :param object/list data: Data for augmentation. It can be list of data (e.g. list
            of string or numpy) or single element (e.g. string or numpy). Numpy format only
            supports audio or spectrogram data. For text data, only support string or
            list of string.
        # :param int num_thread: Number of thread for data augmentation. Use this option
        #     when you are using CPU and n is larger than 1
        :return: Augmented data

        >>> augmented_data = aug.augment(data)

        """

        if data is None or len(data) == 0:
            sys.stdout("Length of data is 0")
            sys.exit(1)

        start_pos, end_pos = aug.get_augment_range_by_coverage(
            data, self.zone, self.coverage
        )

        warp_factor = aug.get_random_factor(self.factor_range[0], self.factor_range[1])

        return (
            aug.manipulate(
                data,
                start_pos=start_pos,
                end_pos=end_pos,
                sampling_rate=self.sampling_rate,
                warp_factor=warp_factor,
            ),
            warp_factor,
        )
