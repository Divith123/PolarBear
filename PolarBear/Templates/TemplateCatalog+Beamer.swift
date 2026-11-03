//
//  TemplateCatalog+Beamer.swift
//  PolarBear
//

extension TemplateCatalog {
    static let beamerSource = #"""
\documentclass{beamer}
\usetheme{default}

\title{Presentation Title}
\author{Your Name}
\date{\today}

\begin{document}

\begin{frame}
  \titlepage
\end{frame}

\begin{frame}{Outline}
  \begin{itemize}
    \item The question
    \item What we did
    \item What we found
  \end{itemize}
\end{frame}

\begin{frame}{A Result}
  \[
    \int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}
  \]
\end{frame}

\end{document}
"""#

    static let exampleSource = #"""
\documentclass[11pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{amsmath,amssymb}
\usepackage{tikz}

\title{PolarBear: A Tour}
\author{}
\date{}

\begin{document}
\maketitle

\section*{What is PolarBear?}
\textbf{PolarBear} is a native editor for \LaTeX{} documents on the Mac. Your files stay
ordinary files in a folder, the PDF is built on your machine, and any AI helper is one you
already run yourself.

\section*{Maths}
The Laplace transform of $t\cos(at)$ is
\[
  \mathcal{L}\{ t \cos(a t) \} = \frac{ s^2 - a^2 }{ (s^2 + a^2)^2 } .
\]

\section*{A table}
\begin{center}
\begin{tabular}{|c|c|c|c|}
  \hline
  1 & 2 & 3 & 4 \\ \hline
  5 & 6 & 7 & 8 \\ \hline
  9 & 10 & 11 & 12 \\ \hline
\end{tabular}
\end{center}

\section*{A drawing}
\begin{center}
\begin{tikzpicture}[scale=1.2]
  \draw[thick, ->] (0,0) -- (3,0) node[right] {$x$};
  \draw[thick, ->] (0,0) -- (0,2) node[above] {$y$};
  \draw[domain=0:2.8, smooth, variable=\x] plot ({\x}, {0.6 + 0.5*sin(deg(\x*2))});
\end{tikzpicture}
\end{center}

\section*{A list}
\begin{enumerate}
  \item Click a line in the PDF with \textbf{Command} held to jump to its source.
  \item Errors appear in the Problems list; click one to go to the line.
  \item Every save is kept in History, so nothing is ever lost.
\end{enumerate}

\end{document}
"""#
}
