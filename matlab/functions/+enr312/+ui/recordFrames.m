function videoFile = recordFrames(fig, nFrames, drawFrame, outDir, fps)
%RECORDFRAMES  Capture an app window frame by frame into <outDir>/simulation.mp4.
%
%   videoFile = enr312.ui.recordFrames(fig, nFrames, @(j) draw(j), outDir, fps)
%
%   drawFrame(j) must update the window for frame j (1..nFrames). Frames are
%   captured with getframe after drawnow, written as Motion-JPEG AVI (the only
%   lossy profile MATLAB offers on Linux), then converted to H.264 MP4 with
%   ffmpeg. If ffmpeg fails the AVI is kept and its name returned, with a warning.
%   The file name, size and method are written into <outDir>/run_config.json if
%   that file exists.

    if nargin < 5, fps = 15; end
    tmp = fullfile(tempdir, sprintf('enr312_rec_%s.avi', char(java.util.UUID.randomUUID)));
    vw = VideoWriter(tmp, 'Motion JPEG AVI'); vw.FrameRate = fps; vw.Quality = 92;
    open(vw); cleaner = onCleanup(@() close(vw));
    for j = 1:nFrames
        if ~isvalid(fig), break; end
        drawFrame(j);
        drawnow;
        writeVideo(vw, getframe(fig));
    end
    clear cleaner;
    mp4 = fullfile(outDir, 'simulation.mp4');
    [st, msg] = system(sprintf(['ffmpeg -y -loglevel error -i "%s" -c:v libx264 -pix_fmt yuv420p ' ...
        '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "%s"'], tmp, mp4));
    if st == 0 && isfile(mp4)
        videoFile = mp4; delete(tmp);
    else
        videoFile = fullfile(outDir, 'simulation.avi'); movefile(tmp, videoFile);
        warning('enr312:record:ffmpeg', 'ffmpeg conversion failed, kept AVI: %s', msg);
    end
    enr312.evidence.attachVideo(outDir, videoFile, fps);
end
