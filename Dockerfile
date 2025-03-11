# Runtime stage
FROM python:3.8 AS builder

RUN apt-get update \
 && apt-get install wget

# Installing dependencies, QOL packages
RUN apt install libx11-dev git bison flex automake libtool ninja-build libxext-dev libncurses-dev python3-dev \
             xfonts-100dpi cython3 libopenmpi-dev python3-scipy cmake zlib1g-dev vim -y

RUN apt-get install               \
                build-essential                \
                libboost-python-dev            \
                libboost-date-time-dev         \
                libboost-filesystem-dev -y
RUN apt-get install               \
                libboost-iostreams-dev         \
                libboost-program-options-dev   \
                libboost-test-dev              \
                libhdf5-dev -y 

# install ISPC
# RUN wget https://github.com/ispc/ispc/releases/download/v1.14.1/ispc-v1.14.1-linux.tar.gz
# RUN tar xfz ispc-v1.14.1-linux.tar.gz
# RUN cp ispc-v1.14.1-linux/bin/ispc /bin

# install GLM
RUN git clone https://github.com/g-truc/glm
WORKDIR glm
RUN git checkout 0.9.9.3
RUN mkdir build
WORKDIR build
RUN cmake .. -GNinja
RUN ninja
RUN ninja install
WORKDIR ../..

# install libsonata
RUN git clone https://github.com/BlueBrain/libsonata
WORKDIR libsonata
RUN git submodule update --init --recursive
RUN mkdir build 
WORKDIR build
RUN cmake .. \
            -GNinja \
            -DEXTLIB_FROM_SUBMODULES=ON \
            -DSONATA_PYTHON=OFF \
            -DSONATA_TESTS=OFF
RUN ninja
RUN ninja install
WORKDIR ../..

# install Brion
RUN git clone --recursive https://github.com/BlueBrain/Brion.git
RUN mkdir Brion/build
WORKDIR Brion/build
RUN cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DEXTLIB_FROM_SUBMODULES=ON ..
RUN ninja
RUN ninja install




# Build stage
FROM bluebrain/rtneuron_builder
RUN ls -alh

#COPY --from=builder boost_1_65_0 .
COPY --from=builder glm .
COPY --from=builder libsonata .
COPY --from=builder Brion .
#COPY --from=builder doxygen-Release_1_8_5 .
#COPY --from=builder gcc-5.4.0 .
#COPY --from=builder hdf5-1.10.3 .
#COPY --from=builder bin .
#COPY --from=builder dev .
#COPY --from=builder home .
#COPY --from=builder lib .
#COPY --from=builder lib64 .

ADD . /emsim
RUN mkdir -p /app/emsim/usr/ /emsim/build/
RUN cd /emsim/build && cmake .. \
    -DCLONE_SUBPROJECTS=ON -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/app/emsim/usr/ && \
    make -j install

WORKDIR /app/emsim
RUN  cp -P /usr/local/lib64/lib*so* /usr/local/lib/lib*so* usr/lib

# APP image
###################
WORKDIR /root
RUN curl -LO https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
chmod +x ./linuxdeploy-x86_64.AppImage


# AppImageTool
RUN curl -LO https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
RUN chmod +x /root/appimagetool-x86_64.AppImage
RUN /root/appimagetool-x86_64.AppImage --appimage-extract

WORKDIR /app/emsim

ADD packaging/AppImage/config .
RUN chmod +x AppRun

CMD ["/root/squashfs-root/AppRun", "/app/emsim", "/tmp/output/emsim_x86_64.AppImage"]
